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

