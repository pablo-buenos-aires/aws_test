

resource "aws_instance" "pub_ubuntu" { # создаем инстанс
  #ami                    = data.aws_ami.ubuntu_24.id
  ami = var.ami_id
  instance_type  = var.instance_type

  subnet_id = var.public_subnet_id # в публичной полдсети
  vpc_security_group_ids = [var.public_sg_id] # группа безопасности
  key_name   = var.key_name # SSH ключ
  associate_public_ip_address = true # выделение внешнего IP
  source_dest_check = false #n чтобы работал NAT

  iam_instance_profile = var.instance_profile_name

  # user_data = file("${path.module}/user_data_public.sh")
  # в образе уже установили софт
  user_data =  <<EOF
# Включаем форвардинг и делаем это постоянным
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-nat.conf #  reboot-safe
sysctl --system

# CIDR подставит terraform
VPC_CIDR="${var.vpc_cidr}"

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
  name_prefix = "l-templ"
  #image_id    = data.aws_ami.ubuntu_24.id
  image_id = "ami-0cdd87dc388f1f6e1"
  instance_type = var.instance_type
  #key_name = aws_key_pair.ssh_aws_key.key_name
  key_name = var.key_name
 # нужен блок
  iam_instance_profile { name = var.instance_profile_name }
  vpc_security_group_ids = [var.private_sg_id]

  #network_interfaces { security_groups = [aws_security_group.private_sg.id] }
}
# -------------------------------------------------------------------------- Asg
resource "aws_autoscaling_group" "priv_asg" {
  name = "priv-asg"
  min_size   = 2
  desired_capacity = 2
  max_size  = 2
  health_check_type  = "EC2" # проверка доступности инстанса
  health_check_grace_period = 120 # время на инит, потом проверка доступности
  capacity_rebalance  = true # если зона отвалится, на других сделает инстансы

  wait_for_capacity_timeout = "10m" # для терраформ, чтобы  ожидать перехода asg в нужное состояние
  # приватные подсети!! (subnets_id, не зоны доступности). Каждая приватная сеть в своей зоне
  vpc_zone_identifier = var.private_subnet_ids

  # привязка Launch Template
  launch_template {
    id      = aws_launch_template.l_templ.id
    version = aws_launch_template.l_templ.latest_version
  }
  # в каком порядке завершать инстансы при уменьшении
  termination_policies = ["OldestInstance", "ClosestToNextInstanceHour"] # старые и где оплаченые часы меньше

  depends_on = [var.private_subnet_ids]         # чтобы SSM работал
 # depends_on = [var.vpc_id] # Terraform поймет зависимость через входную переменную
}



