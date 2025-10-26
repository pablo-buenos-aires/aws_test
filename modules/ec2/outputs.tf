

output "asg_name"   { value = aws_autoscaling_group.priv_asg.name }
output "asg_arn"    { value = aws_autoscaling_group.priv_asg.arn }

output "instance_profile_name" { value = var.instance_profile_name }

output "public_instance_id"  { value = aws_instance.pub_ubuntu.id } # id инстанса
output "public_ip"    { value = aws_instance.pub_ubuntu.public_ip }

output "public_dns"   { value = aws_instance.pub_ubuntu.public_dns } # DNS

output "l_templ_id" { value = aws_launch_template.l_templ.id }
output "l_templ_arn" { value = aws_launch_template.l_templ.arn }
#output "l_templ__latest_version" { value = aws_launch_template.l_templ.latest_version }
