
# -------------------------------------------- переменные для доступа из др. модулей
output "vpc_id" { value = aws_vpc.main_vpc.id }
output "vpc_cidr" { value = aws_vpc.main_vpc.cidr_block}
output "igw_id" { value = aws_internet_gateway.igw.id }

# зоны доступности для asg - такие де, как для vpc, проброс входа
output "vpc_asg_azs" {  value = var.vpc_azs }
output "region" {  value = local.region }

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