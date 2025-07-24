variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "ap-south-1"
}
variable "environment" {
  description = "Deployment environment name (dev/staging/prod)"
  type        = string
  default     = "dev"
}
variable "cluster_name" {
  description = "Name of the EKS cluster to create"
  type        = string
  default     = "api-flask-cluster"
}
