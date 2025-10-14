#variable "vpc_name" { type = string }


variable "vpc_cidr" { type = string }
# списки зон для подсетей, для публичной - первая в списке
variable "vpc_azs" { type = list(string) }

variable "public_subnet_cidr" { type = string }
variable "private_subnet_cidrs" { type = list(string) }

# основная VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr
  #enable_dns_support   = true
  enable_dns_hostnames = true
}

 # подсети
resource "aws_subnet" "private_subnet" {
  count = length(var.private_subnet_cidrs) #
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = var.private_subnet_cidrs[count.index]
  availability_zone = var.vpc_azs[count.index]
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.vpc_azs[0]
  map_public_ip_on_launch = true             # Автоназначение публичных IP в этой подсети
  # tags = {  Name = "${var.vpc_name}-public" }
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


/*
# -отключим маршрут, доступ по SSM теперь
resource "aws_route" "rt_priv_route" { # нужен отдельно маршрут, инлайн нельзя для instance_id
  route_table_id         = aws_route_table.rt_priv.id
  destination_cidr_block = "0.0.0.0/0"
 # instance_id = aws_instance.pub_ubuntu.id  #  NAT/bastion инстанс
  network_interface_id   = aws_instance.pub_ubuntu.primary_network_interface_id # в новых провайдерах через ENI
  depends_on = [aws_instance.pub_ubuntu]   # дождаться инстанса
  }
*/



# -------------------------------------------- переменные для доступа из др. модулей
output "vpc_id" { value = aws_vpc.main_vpc.id }
output "vpc_cidr" { value = aws_vpc.main_vpc.cidr_block}
output "igw_id" { value = aws_internet_gateway.igw.id }

# зоны доступности для asg - такие де, как для vpc
output "vpc_asg_azs" {  value = var.vpc_azs }

output "public_sg_id" {   value = aws_security_group.public_sg.id } # SG
output "private_sg_id" {   value = aws_security_group.private_sg.id }
output "endpoint_sg_id" {   value = aws_security_group.endpoint_sg.id }

# подсети
output "public_subnet_id" { value  = aws_subnet.public_subnet.id }
output "private_subnet_ids" {  value = aws_subnet.private_subnet[*].id }
output "private_rt_ass_ids" {  value = aws_route_table_association.rt_priv_ass[*].id }


# таблицы и маршруты
output "public_rt_id" { value  = aws_route_table.rt_pub }
output "private_rt_id" { value  = aws_route_table.rt_priv }
# вывод  маршрутов
output "rt_pub_routes" {  value = aws_route_table.rt_pub.route }  # вывод маршрутов
output "rt_priv_routes" {  value = aws_route_table.rt_priv.route }



