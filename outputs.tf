
# output "account_id" { value = data.aws_caller_identity.me.account_id }
output "arn"        { value = data.aws_caller_identity.me.arn } # вывод параметров ресурса
output "region"     { value = data.aws_region.here.region } # и региона

output "vpc_id"   { value =  aws_vpc.my_vpc.id } # вывод vpc id


output "myAZ_public"   { value =  aws_subnet.public_subnet.availability_zone } # вывод aZ
output "public_subnet" { value  = aws_subnet.public_subnet.id }
output "private_subnet" { value  = aws_subnet.private_subnet.id }
