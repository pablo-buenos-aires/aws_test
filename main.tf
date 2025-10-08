resource "aws_vpc" "my_vpc" { # создаем vpc
  	cidr_block           = "10.0.0.0/16" # диапазон адресов
  	enable_dns_hostnames = true    # включаем dns hostname, для доступа к публичному инстансу	
	}
  
resource "aws_subnet" "public_subnet" { # публичная подсеть
  	vpc_id            = aws_vpc.my_vpc.id
  	cidr_block        = "10.0.1.0/24" 
  	availability_zone = data.aws_availability_zones.zones.names[0]
	}

resource "aws_subnet" "private_subnet" { # приватная подсеть в той же зоне 
  	vpc_id            = aws_vpc.my_vpc.id
  	cidr_block        = "10.0.2.0/24" 
  	availability_zone = data.aws_availability_zones.zones.names[0]
	}		

# ------------------------------------------------------------------------------------------- IGW
resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.my_vpc.id } # IGW для доступа VPC в интернет

# -------------------------------------------------------------------------------------------  bastion/nat SG
resource "aws_security_group" "nat_sg" {  # разрешаем входящий трафик по SSH и любой из приватной подсети, для NAT
   	vpc_id      = aws_vpc.my_vpc.id
	ingress {
    	from_port   = 22
    	to_port     = 22
    	protocol    = "tcp"
    	cidr_blocks = ["0.0.0.0/0"] # со всех адресов
   	}
 /*
   	ingress { # for private subnet, NAT
    	from_port   = 0
    	to_port     = 0
    	protocol    = "-1"  #  любой протокол
    	cidr_blocks = [aws_subnet.private_subnet.cidr_block]
  	}
  	*/
  	egress { # исходящий трафик открыт 
    	from_port   = 0
    	to_port     = 0
    	protocol    = "-1"
    	cidr_blocks = ["0.0.0.0/0"]
  	}
}
# ------------------------------------------------------------------------------------------- SG приватный инстанс
resource "aws_security_group" "private_sg" {
   	vpc_id      = aws_vpc.my_vpc.id
	ingress { # разрешаем входящий трафик по SSH от бастиона
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        security_groups = [aws_security_group.nat_sg.id]
    }
  	egress { # исходящий трафик открыт
    	from_port   = 0
    	to_port     = 0
    	protocol    = "-1"
    	cidr_blocks = ["0.0.0.0/0"]
  	}
}
# ------------------------------------------------------------------------------------------- SG endpoints
resource "aws_security_group" "endpoint_sg" { # для SSM endpoints
   	vpc_id      = aws_vpc.my_vpc.id
	ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.my_vpc.cidr_block]
   }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
}
# ------------------------------------------------------------------------------------------- ключи
resource "tls_private_key" "ssh_key" { # генерация ключа через встроенного провайдера
	algorithm = "RSA" 
	rsa_bits  = 2048 
	}

resource "aws_key_pair" "ssh_aws_key" {  # регистрируем ключ

  	public_key = tls_private_key.ssh_key.public_key_openssh # ключ в формате Openssh
    key_name   = "tf-ssh-key" # без этого не связывает ключи корректно

}

resource "local_file" "file_ssh_priv" { # без provisioner — через local_file
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/ssh-key.pem"
  file_permission = "0400"
}

resource "local_file" "file_ssh_pub" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/ssh-key.pub"
}
# --------------------------------------------------------------------------------------- инстансы

resource "aws_instance" "pub_ubuntu" { # создаем инстанс
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = var.t3
  subnet_id              = aws_subnet.public_subnet.id # в публичной полдсети
  vpc_security_group_ids = [aws_security_group.nat_sg.id] # группа безопасности
  key_name               = aws_key_pair.ssh_aws_key.key_name # созданный выше SSH ключ
  associate_public_ip_address = true # выделение внешнего IP
  source_dest_check = false #n чтобы работал NAT

  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name # профиль от роли SSM

  user_data = <<EOT
#!/bin/bash
set -euxo pipefail  # error,undefuned, exec, честные пайплайны ошибок
export DEBIAN_FRONTEND=noninteractive # чтобы не было вопросов
echo "netfilter-persistent netfilter-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "netfilter-persistent netfilter-persistent/autosave_v6 boolean false" | debconf-set-selections

#  пакеты для автосохранения правил
apt-get update -y
apt-get install -y netfilter-persistent

# Включаем форвардинг и делаем это постоянным
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-nat.conf #  reboot-safe
sysctl --system

# CIDR вашей VPC подставит Terraform
VPC_CIDR="${aws_vpc.my_vpc.cidr_block}"

# Аккуратно берём внешний интерфейс по default route (IPv4)
EXT_IF="$(ip -o -4 route show to default | awk '{print $5}' | head -n1)"

# Добавляем MASQUERADE, если ещё нет (чтобы не дублировать)
if ! iptables -t nat -C POSTROUTING -s "$VPC_CIDR" -o "$EXT_IF" -j MASQUERADE 2>/dev/null; then
  iptables -t nat -A POSTROUTING -s "$VPC_CIDR" -o "$EXT_IF" -j MASQUERADE
fi
#
netfilter-persistent save
systemctl enable --now netfilter-persistent
EOT

}

resource "aws_instance" "priv_ubuntu" { # создаем приватный инстанс
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = var.t3
  subnet_id              = aws_subnet.private_subnet.id # в приватной полдсети
  vpc_security_group_ids = [aws_security_group.private_sg.id] # группа безопасности
  key_name               = aws_key_pair.ssh_aws_key.key_name # используеми тот же ключ

   iam_instance_profile = aws_iam_instance_profile.ssm_profile.name # профиль SSM
 }


# ---------------------------------------------------------------------------------------- маршруты
resource "aws_route_table" "rt_pub" { # марш. таблица для публичной подсети
  	vpc_id = aws_vpc.my_vpc.id
  	route {
    		cidr_block = "0.0.0.0/0"                 # исходящий трафик во все подсети
    		gateway_id = aws_internet_gateway.igw.id # идёт через igw
  		}
	}
resource "aws_route_table_association" "rt_pub_ass" { # Привязка таблицы к публичной подсети
 	subnet_id      = aws_subnet.public_subnet.id
  	route_table_id = aws_route_table.rt_pub.id
	}

resource "aws_route_table" "rt_priv" {
    vpc_id = aws_vpc.my_vpc.id
    }

resource "aws_route" "rt_priv_route" { # нужен отдельно маршрут, инлайн нельзя для instance_id
  route_table_id         = aws_route_table.rt_priv.id
  destination_cidr_block = "0.0.0.0/0"
 # instance_id = aws_instance.pub_ubuntu.id  #  NAT/bastion инстанс
  network_interface_id   = aws_instance.pub_ubuntu.primary_network_interface_id # в новых провайдерах через ENI
  depends_on = [aws_instance.pub_ubuntu]   # дождаться инстанса
  }

/* # отключим, доступ по SSM теперь
resource "aws_route_table_association" "rt_priv_ass" { # связь с приват.
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.rt_priv.id
}
*/

#--------------------------------------------------------------------------- настройка SSM для инстансов
resource "aws_iam_role" "ssm_role" { # роль создаем
  name = "ssm_role_name"
  assume_role_policy = jsonencode({  # для получения JSON для амазон
    Version = "2012-10-17" # обязательное поле
    Statement = [{  #  список правил
      Action    = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" } # кто может эту роль использовать, в т.ч инстансы ec2s

    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" { # добавление политики к роли для SSM длоступа
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" { # профиль на базе роли, для привязки к инстансам
  name = "ssm_profile_name"
  role = aws_iam_role.ssm_role.name
}

#------------------------------------------------------------------------- настройка  endpoints
resource "aws_vpc_endpoint" "endpoints" {
   for_each = {
    ssm         = "com.amazonaws.${data.aws_region.here.region}.ssm"
    ec2messages = "com.amazonaws.${data.aws_region.here.region}.ec2messages"
    ssmmessages = "com.amazonaws.${data.aws_region.here.region}.ssmmessages"
  }
  vpc_id              = aws_vpc.my_vpc.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids          = [aws_subnet.private_subnet.id] # subnets
  security_group_ids  = [aws_security_group.endpoint_sg.id]
}

# красивый вывод
output "ssm_interface_endpoints" { # вывод эндпоинто
  value = {
    for k, endp in aws_vpc_endpoint.endpoints: # генератор k -> ключ словаря
    k => { # значения списком
      id           = endp.id
      service      = endp.service_name
      # dns_names    = endp.dns_entry[*].dns_name
      # network_ifcs = endp.network_interface_ids # какие интерфейсы созданы для эндпоинта
    }
  }
}
