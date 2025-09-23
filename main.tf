provider "aws" {
  region = "us-west-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}
# load my public key en aws
resource "aws_key_pair" "my_key" {
  key_name   = "my-ssh-key"
  public_key = file("mykeypair.pub")
}

resource "aws_security_group" "ssh_security_group" {
  name        = "allow-ssh"
  description = "Allow inbound SSH traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Внимание: для продакшена лучше ограничить своим IP!
  }
/*
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
*/
  tags = {
    Name = "allow-ssh-group"
  }
}

resource "aws_instance" "test_server1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.my_key.key_name

  vpc_security_group_ids = [aws_security_group.ssh_security_group.id] 
  subnet_id              = module.vpc.public_subnets[0]
  
  associate_public_ip_address = true 

  tags = {
    Name = "t3micro-1"
  }
}

resource "aws_instance" "test_server2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]

  tags = {
    Name = "t3micro-2"
  }
}

resource "aws_instance" "test_server3" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.database_subnets[0]

  tags = {
    Name = "t3micro-3"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = "example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  
  database_subnets    = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_dns_hostnames    = true
  map_public_ip_on_launch = true
}
