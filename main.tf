# ------------------------------------------------------------------------------- /modules
module "vpc" {
  source              = "./modules/vpc"
  #vpc_name            = "test_vpc"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr =  "10.0.1.0/24"
  private_subnet_cidrs = ["10.0.2.0/24", "10.0.3.0/24"] # для каждой подсети должно быть ссответствие azs
  vpc_azs = ["sa-east-1a", "sa-east-1b"] # из первого возьмется регион для эндпоинтов ssm
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
  #ami                    = data.aws_ami.ubuntu_24.id
  ami = "ami-0cdd87dc388f1f6e1"
  instance_type          = var.t3
  subnet_id              = module.vpc.public_subnet_id # в публичной полдсети
  vpc_security_group_ids = [module.vpc.public_sg_id] # группа безопасности
  key_name               = aws_key_pair.ssh_aws_key.key_name # созданный выше SSH ключ
  associate_public_ip_address = true # выделение внешнего IP
  source_dest_check = false #n чтобы работал NAT

  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name # профиль от роли SSM

  # user_data = file("${path.module}/user_data_public.sh")
  # в образе уже установили софт
  user_data =  <<EOF
# Включаем форвардинг и делаем это постоянным
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-nat.conf #  reboot-safe
sysctl --system

# CIDR подставит terraform
VPC_CIDR="${module.vpc.vpc_cidr}"

# Аккуратно берём внешний интерфейс по default route (IPv4)
EXT_IF="$(ip -o -4 route show to default | awk '{print $5}' | head -n1)"

# Добавляем MASQUERADE, если ещё нет (чтобы не дублировать)
if ! iptables -t nat -C POSTROUTING -s "$VPC_CIDR" -o "$EXT_IF" -j MASQUERADE 2>/dev/null; then
  iptables -t nat -A POSTROUTING -s "$VPC_CIDR" -o "$EXT_IF" -j MASQUERADE
fi
#
netfilter-persistent save
systemctl enable --now netfilter-persistent
EOF
}
# ---------------------------------------------------------- два приватный инстанса в разных зонах доступности
# шаблон без привязки к подсетям
resource "aws_launch_template" "l_templ" {
  name_prefix = "l-templ-1"
  image_id    = data.aws_ami.ubuntu_24.id
  instance_type = var.t3
  key_name = aws_key_pair.ssh_aws_key.key_name
 # нужен блок
  iam_instance_profile { name = aws_iam_instance_profile.ssm_profile.name }
  vpc_security_group_ids = [module.vpc.private_sg_id]

  #network_interfaces { security_groups = [aws_security_group.private_sg.id] }
}
# -------------------------------------------------------------------------- Asg
resource "aws_autoscaling_group" "priv_asg" {
  name                      = "priv-asg"
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 2
  health_check_type         = "EC2" # проверка доступности инстанса
  health_check_grace_period = 120 # время на инит, потом проверка доступности
  capacity_rebalance        = true # если зона отвалится, на других сделает инстансы

  wait_for_capacity_timeout = "10m" # для терраформ, чтобы  ожидать перехода asg в нужное состояние
  # приватные подсети!! (subnets_id, не зоны доступности). Каждая приватная сеть в своей зоне
  vpc_zone_identifier = [for s in module.vpc.private_subnet_ids : s]

  # привязка Launch Template
  launch_template {
    id      = aws_launch_template.l_templ.id
    version = aws_launch_template.l_templ.latest_version
  }
  # в каком порядке завершать инстансы при уменьшении
  termination_policies = ["OldestInstance", "ClosestToNextInstanceHour"] # старые и где оплаченые часы меньше

  depends_on = [ module.vpc]         # чтобы SSM работал

}
/*
# Null resource, который зависим от ASG, и выполняет команду AWS CLI
resource "null_resource" "get_priv_instances" {
  depends_on = [aws_autoscaling_group.priv_asg]

  provisioner "local-exec" {
    command = <<EOT
      aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names ${aws_autoscaling_group.priv_asg.name} \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output json > asg_instances.json
    EOT
  }
} */

resource "terraform_data" "get_priv_instances" {
  # 🔁 форсируем замену ресурса на каждом плане/аплае
  triggers_replace = timestamp()  # <<< меняется каждый apply => ресурс пересоздаётся
  depends_on = [aws_autoscaling_group.priv_asg]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"] # без этого в одну строу команды
    command = <<EOT
set -euo pipefail
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${aws_autoscaling_group.priv_asg.name}" \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output json > asg_instances.json
EOT
  }
}

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

