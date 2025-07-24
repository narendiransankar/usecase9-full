variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "aws_region" { type = string }
variable "cluster_oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS cluster OIDC provider"
}

variable "cluster_oidc_provider_id" {
  type        = string
  description = "ID (path) of the EKS cluster OIDC provider"
}