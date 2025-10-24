
# output "account_id" { value = data.aws_caller_identity.me.account_id }
output "arn"        { value = data.aws_caller_identity.me.arn } # вывод параметров ресурса
output "region_here"     { value = data.aws_region.here.region } # и региона
output "region_from_vpc"     { value = module.vpc.region}
output "private_subnet_ids" {  value = module.vpc.private_subnet_ids }

//output "region_privider"     { value = var.region}
output "public_ip"    { value = module.ec2.public_ip }

output "asg_name"   { value =  module.ec2.asg_name }
output "asg_arn"    { value = module.ec2.asg_arn }

output "instance_profile_name_ec2" { value = module.ec2.instance_profile_name }

#output "public_instance_id"  { value = aws_instance.pub_ubuntu.id } # id инстанса
#output "private_instance_id_1"  { value = aws_instance.priv_ubuntu_1.id } # id инстанса 2
#output "private_instance_id_2"  { value = aws_instance.priv_ubuntu_2.id } # id инстанса 2

output "public_dns"   { value = module.ec2.public_dns } # DNS

output "l_templ_id" { value = module.ec2.l_templ_id }
output "l_templ_arn" { value = module.ec2.l_templ_arn }# и региона
//output "vpc_id"   { value =  aws_vpc.my_vpc.id } # вывод vpc id

/*
output "myAZ_public"   { value =  aws_subnet.public_subnet.availability_zone } # вывод aZ
output "public_subnet_id" { value  = aws_subnet.public_subnet.id }
output "private_subnet_id_1" { value  = aws_subnet.private_subnet_1.id }
output "private_subnet_id_2" { value  = aws_subnet.private_subnet_2.id }

# вывод инлайн-маршрутов
output "rt_pub_routes" {  value = aws_route_table.rt_pub.route }  # вывод маршрутов
output "rt_priv_routes" {  value = aws_route_table.rt_priv.route }
*/
#output "rt_priv_routes" {  value = data.aws_route_table.rt_priv_read.routes }
# ------------------------------------------------------------------------------------------- instaces

#output "image_name" { value = data.aws_ami.ubuntu_24.name } # имя образа


#output "asg_instance_ids" { value = aws_autoscaling_group.priv_asg.instances }
# инстансы, получаемые из вызова aws через локальный файл
output "asg_instance_ids" { value = jsondecode(data.local_file.asg_instances_file.content) }