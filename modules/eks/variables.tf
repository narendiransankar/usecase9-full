variable "cluster_name" {
  description = "Name for the EKS cluster"
  type        = string
}
variable "vpc_id" {
  description = "VPC ID where EKS will be deployed"
  type        = string
}
variable "public_subnet_ids" {
  description = "List of public subnet IDs (for load balancers or cluster if needed)"
  type        = list(string)
}
variable "private_subnet_ids" {
  description = "List of private subnet IDs for worker nodes and control plane"
  type        = list(string)
}
variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.small"
}
variable "desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}
variable "max_capacity" {
  description = "Maximum number of worker nodes (scaling)"
  type        = number
  default     = 3
}
variable "min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}
variable "enable_cluster_logs" {
  description = "Enable control plane logs in CloudWatch for API, audit, etc."
  type        = bool
  default     = true
}
