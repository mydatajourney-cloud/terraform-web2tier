
# VPC variable
variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["10.0.0.0/24", "10.0.16.0/24"]
}
 
variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
 default     = ["10.0.128.0/24", "10.0.144.0/24", "10.0.160.0/24", "10.0.176.0/24"]
}

variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

# ec2 variables
variable "ami_id" {
  default = "ami-09786d938184910bf"
  type        = string
}
variable "instance_type" {
  default = "t2.micro"
  type        = string
}