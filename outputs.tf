
# output "account_id" { value = data.aws_caller_identity.me.account_id }
output "arn"        { value = data.aws_caller_identity.me.arn } # вывод параметров ресурса
output "region"     { value = data.aws_region.here.region } # и региона

output "vpc_id"   { value =  aws_vpc.my_vpc.id } # вывод vpc id


output "myAZ_public"   { value =  aws_subnet.public_subnet.availability_zone } # вывод aZ
output "public_subnet_id" { value  = aws_subnet.public_subnet.id }
output "private_subnet_id_1" { value  = aws_subnet.private_subnet_1.id }
output "private_subnet_id_2" { value  = aws_subnet.private_subnet_2.id }

# вывод инлайн-маршрутов
output "rt_pub_routes" {  value = aws_route_table.rt_pub.route }  # вывод маршрутов
output "rt_priv_routes" {  value = aws_route_table.rt_priv.route }

#output "rt_priv_routes" {  value = data.aws_route_table.rt_priv_read.routes }
# ------------------------------------------------------------------------------------------- instaces

output "image_name" { value = data.aws_ami.ubuntu_24.name } # имя образа
output "public_instance_id"  { value = aws_instance.pub_ubuntu.id } # id инстанса
#output "private_instance_id_1"  { value = aws_instance.priv_ubuntu_1.id } # id инстанса 2
#output "private_instance_id_2"  { value = aws_instance.priv_ubuntu_2.id } # id инстанса 2

output "public_ip"    { value = aws_instance.pub_ubuntu.public_ip }
#output "private_ip_1"    { value = aws_instance.priv_ubuntu_1.private_ip } #
#output "private_ip_2"    { value = aws_instance.priv_ubuntu_2.private_ip } #

output "public_dns"   { value = aws_instance.pub_ubuntu.public_dns } # DNS

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

output "l_templ_1_id" { value = aws_launch_template.l_templ.id }
output "l_templ_arn" { value = aws_launch_template.l_templ.arn }
output "l_templ_1_latest_version" { value = aws_launch_template.l_templ.latest_version }

#output "asg_instance_ids" { value = aws_autoscaling_group.priv_asg.instances }
# инстансы, получаемые из вызова aws через локальный файл
output "asg_instance_ids" {
  value = jsondecode(data.local_file.asg_instances_file.content)
}