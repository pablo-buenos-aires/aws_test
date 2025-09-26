terraform { # блок настройки терраформ
	required_version = ">= 1.2" # страховка от несовместимости кода со старой версией терраформ
	# офиц. плагин для авс, 6 версия актуальная
	required_providers { aws = {  source   = "hashicorp/aws",  version = ">= 6.0"  } } 
	
	}
 
provider "aws" { region = "sa-east-1" } # блок провайдера
data "aws_caller_identity" "me" {} #  ресурсы для запроса моего arn, кем являюсь 
data "aws_region" "here" {} # запроса региона

# output "account_id" { value = data.aws_caller_identity.me.account_id }
output "arn"        { value = data.aws_caller_identity.me.arn } # вывод параметров ресурса
output "region"     { value = data.aws_region.here.region } # и региона

resource "aws_vpc" "my_vpc" { # создаем vpc 
  cidr_block           = "10.0.0.0/16" # диапазон адресов
  enable_dns_hostnames = true    # включаем dns hostname, для доступа к публичному инстансу
  }
  
output "vpc_id"   { value =  aws_vpc.my_vpc.id } # вывод vpc id

data "aws_availability_zones" "zones" { state = "available" } # встроенный источник данных

resource "aws_subnet" "public_subnet" { # публичная подсеть
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24" 
  availability_zone = data.aws_availability_zones.zones.names[0]
}

resource "aws_subnet" "private_subnet" { # приватная подсеть в той же зоне 
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24" 
  availability_zone = data.aws_availability_zones.zones.names[0]
}

output "myAZ_public"   { value =  aws_subnet.public_subnet.availability_zone } # вывод aZ

