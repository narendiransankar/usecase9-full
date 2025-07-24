output "eks_cluster_name" {
  value = module.eks.cluster_name
}
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
  description = "URL of the EKS API server"
}
output "eks_cluster_security_group" {
  value = module.eks.cluster_security_group_id
}
output "flask_app_ecr_url" {
  value = module.ecr.repository_url
  description = "ECR repository URL for the Flask app"
}
