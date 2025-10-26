// приходят из модкля впц
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_id"   { type = string }
variable "public_sg_id"      { type = string }
variable "private_sg_id"  { type = string }
variable "ami_id"          { type = string }

variable "instance_type"   {
          type = string
          default = "t3.micro"
}

variable "key_name"          { type = string }
variable "instance_profile_name" { type = string}
// for nat
variable "vpc_cidr"             { type = string }
