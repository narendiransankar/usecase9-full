variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "azs" {
  description = "List of Availability Zones for subnets"
  type        = list(string)
  # default can be set via data lookup if desired; here expect override from module call
}
variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
  default     = []
}
variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets"
  type        = list(string)
  default     = []
}
variable "env" {
  description = "environemtns"
  type        = string
}

variable "name_prefix" {
  description = "null"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "cluster name"
  type        = string
}

