data "aws_caller_identity" "me" {} #  ресурсы для запроса моего arn, кем являюсь
data "aws_region" "here" {} # запроса региона для output

data "aws_availability_zones" "zones" { state = "available" } # встроенный источник данных

data "aws_ami" "ubuntu_24" { # находим последний образ ubuntu 24.04
  most_recent = true
  owners      = ["099720109477"] # идентификатор разработчика ubuntu
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# data "aws_route_table" "rt_priv_read" { route_table_id = aws_route_table.rt_priv.id }

# from amazon
data "aws_autoscaling_group" "data_priv_asg" { name = aws_autoscaling_group.priv_asg.name }
