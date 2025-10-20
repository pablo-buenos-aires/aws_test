#variable "vpc_name" { type = string }


variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}
# списки зон для подсетей, для публичной - первая в списке
variable "vpc_azs" {
  type = list(string)
  default = ["sa-east-1a", "sa-east-1b"]

  validation {
    condition = length(var.vpc_azs) == 2
    error_message = "❌  Зон должно быть 2"
  }
}

variable "public_subnet_cidr" {
  type = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  type = list(string)
  default = ["10.0.2.0/24", "10.0.3.0/24"]
  validation {
    condition = length(var.vpc_azs) == length(var.private_subnet_cidrs)
    error_message = "❌  Количество зон и подсетей не совпадают"
  }
}

# делаем регион для ssm endpoints
locals {
  az1 = try(element(var.vpc_azs, 0),  error("❌ Количество зон = 0"))
  region = substr(local.az1, 0, length(local.az1) - 1)
  err_priv = length(var.private_subnet_cidrs) != length(var.vpc_azs) ?  error("❌ Кол. зон != кол. подсетей") : true
 }

# основная VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
}

 # подсети
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.vpc_azs[0]
  map_public_ip_on_launch = true             # Автоназначение публичных IP в этой подсети
  # tags = {  Name = "${var.vpc_name}-public" }
}

resource "aws_subnet" "private_subnet" {
  count = length(var.private_subnet_cidrs) #
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = var.vpc_azs[count.index]
}



resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.main_vpc.id } # IGW для доступа VPC в интернет

# -------------------------------------------------------------------------------------------  bastion/nat SG
resource "aws_security_group" "public_sg" {  # разрешаем входящий трафик по SSH и любой из приватной подсети, для NAT
   	vpc_id      = aws_vpc.main_vpc.id
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
    	cidr_blocks = var.private_subnet_cidrs
  	}

  	egress { # исходящий трафик открыт
    	from_port   = 0
    	to_port     = 0
    	protocol    = "-1"
    	cidr_blocks = ["0.0.0.0/0"]
  	}
}
# ------------------------------------------------------------------------------------------- SG приватный инстанс
resource "aws_security_group" "private_sg" {
   	vpc_id      = aws_vpc.main_vpc.id
	ingress { # разрешаем входящий трафик по SSH от бастиона
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        security_groups = [aws_security_group.public_sg.id]
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
   	vpc_id      = aws_vpc.main_vpc.id
	ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main_vpc.cidr_block]
   }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
}

# ---------------------------------------------------------------------------------------- маршруты
resource "aws_route_table" "rt_pub" { # марш. таблица для публичной подсети
  	vpc_id = aws_vpc.main_vpc.id
  	route {
    		cidr_block = "0.0.0.0/0"                 # исходящий трафик во все подсети
    		gateway_id = aws_internet_gateway.igw.id # идёт через igw
  		}
	}

resource "aws_route_table" "rt_priv" { vpc_id = aws_vpc.main_vpc.id  }

# связь приватных таблиц с подсетями
resource "aws_route_table_association" "rt_priv_ass" { # связь с приват 1.
  count = length(var.private_subnet_cidrs) #
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.rt_priv.id
}

resource "aws_route_table_association" "rt_pub_ass" { # Привязка таблицы к публичной подсети
 	subnet_id      = aws_subnet.public_subnet.id
  	route_table_id = aws_route_table.rt_pub.id
	}


# -отключим маршрут, доступ по SSM теперь
/*
resource "aws_route" "rt_priv_route" { # нужен отдельно маршрут, инлайн нельзя для instance_id
  route_table_id         = aws_route_table.rt_priv.id
  destination_cidr_block = "0.0.0.0/0"
 # instance_id = aws_instance.pub_ubuntu.id  #  NAT/bastion инстанс
  network_interface_id   = aws_instance.pub_ubuntu.primary_network_interface_id # в новых провайдерах через ENI
  depends_on = [aws_instance.pub_ubuntu]   # дождаться инстанса
  }
*/
#------------------------------------------------------------------------- настройка  endpoints
resource "aws_vpc_endpoint" "endpoints" {
   for_each = {
    ssm         = "com.amazonaws.${local.region}.ssm"
    ec2messages = "com.amazonaws.${local.region}.ec2messages"
    ssmmessages = "com.amazonaws.${local.region}.ssmmessages"
  }
  vpc_id              = aws_vpc.main_vpc.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids          = aws_subnet.private_subnet[*].id # в каждой подсети эндпоинты
  security_group_ids  = [aws_security_group.endpoint_sg.id]
}





