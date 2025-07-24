output "vpc_id" {
  value       = aws_vpc.this.id
  description = "ID of the VPC"
}
output "public_subnets" {
  value       = [for subnet in aws_subnet.public[*] : subnet.id]
  description = "IDs of public subnets"
}
output "private_subnets" {
  value       = [for subnet in aws_subnet.private[*] : subnet.id]
  description = "IDs of private subnets"
}
