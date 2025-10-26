
variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}
# списки зон для подсетей, для публичной - первая в списке
variable "vpc_azs" {
  type = list(string)
  default = ["sa-east-1a", "sa-east-1b"]

  validation {
    condition = length(var.vpc_azs) == 2
    error_message = "❌  Зон должно быть 2"
  }
}

variable "public_subnet_cidr" {
  type = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  type = list(string)
  default = ["10.0.2.0/24", "10.0.3.0/24"]
  validation {
    condition = length(var.vpc_azs) == length(var.private_subnet_cidrs)
    error_message = "❌  Количество зон и подсетей не совпадают"
  }
}