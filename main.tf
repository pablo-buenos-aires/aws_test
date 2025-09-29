terraform { # блок настройки терраформ
	required_version = ">= 1.2" # страховка от несовместимости кода со старой версией терраформ
	# офиц. плагин для авс, 6 версия актуальная
	required_providers { aws = {  source   = "hashicorp/aws",  version = ">= 6.0"  } } 
	
	}
 
provider "aws" { region = "sa-east-1" } # блок провайдера
data "aws_caller_identity" "me" {} #  ресурсы для запроса моего arn, кем являюсь 
data "aws_region" "here" {} # запроса региона

# output "account_id" { value = data.aws_caller_identity.me.account_id }
output "arn"        { value = data.aws_caller_identity.me.arn } # вывод параметров ресурса
output "region"     { value = data.aws_region.here.region } # и региона

# ----------------------------------------------------------------------------- VPC, подсети
resource "aws_vpc" "my_vpc" { # создаем vpc 
  	cidr_block           = "10.0.0.0/16" # диапазон адресов
  	enable_dns_hostnames = true    # включаем dns hostname, для доступа к публичному инстансу	
	}
  
output "vpc_id"   { value =  aws_vpc.my_vpc.id } # вывод vpc id

data "aws_availability_zones" "zones" { state = "available" } # встроенный источник данных

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

output "myAZ_public"   { value =  aws_subnet.public_subnet.availability_zone } # вывод aZ
output "my_subnets" { # мои подсети
	value       = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id] # вывод списком
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

   	ingress { # for private subnet, NAT
    	from_port   = 0
    	to_port     = 0
    	protocol    = "-1"  #  любой протокол
    	cidr_blocks = [aws_subnet.private_subnet.cidr_block]
  	}
  	
  	egress { # исходящий трафик открыт 
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
  #key_name   = "terraform-aws-key"  # имя ключей в амазон
  	public_key = tls_private_key.ssh_key.public_key_openssh # ключ в формате Openssh

  	# Сохраняем приватный ключ в файл локально, утанавливаем права только чтение для владельца
  	provisioner "local-exec" {
   	 command = <<EOT
    	  echo '${tls_private_key.ssh_key.private_key_pem}' > ssh-key.pem
    	  echo '${tls_private_key.ssh_key.public_key_openssh}' > ssh-key.pub
     	 chmod 400 ssh-key.pem
    	EOT
  	}
}
# --------------------------------------------------------------------------------------- публичный инстанс
data "aws_ami" "ubuntu_24" { # находим последний образ ubuntu 24.04
  most_recent = true
  owners      = ["099720109477"] # идентификатор разработчика ubuntu
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "pub_ubuntu" { # создаем инстанс
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id # создаем в публичной полдсети
  vpc_security_group_ids = [aws_security_group.nat_sg.id] # группа безопасности
  key_name               = aws_key_pair.ssh_aws_key.key_name # созданный выше SSH ключ
  associate_public_ip_address = true # выделение внешнего IP
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

resource "aws_instance" "priv_ubuntu" { # создаем приватный инстанс
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet.id # создаем в приватной полдсети
  vpc_security_group_ids = [aws_security_group.private_sg.id] # группа безопасности
  key_name               = aws_key_pair.ssh_aws_key.key_name # используеми тот же ключ
 }

output "bastion_name" { value = data.aws_ami.ubuntu_24.name } # имя образа
output "public_instance_id"  { value = aws_instance.pub_ubuntu.id } # id инстанса
output "public_ip"    { value = aws_instance.pub_ubuntu.public_ip } # публичный IP
output "public_dns"   { value = aws_instance.pub_ubuntu.public_dns } # DNS

output "private_instance_id"  { value = aws_instance.priv_ubuntu.id } # id инстанса
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

output "rt_pub_routes" {  value = aws_route_table.rt_pub.route }  # вывод маршрутов


# ------------------------------------------------------------------------------------------- NAT