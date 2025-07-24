output "cluster_name" {
  value = aws_eks_cluster.this.name
}
output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "EKS cluster API server endpoint"
}
output "cluster_certificate_authority" {
  value       = aws_eks_cluster.this.certificate_authority[0].data
  description = "Base64 encoded CA certificate for cluster"
}
output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}
output "node_security_group_id" {
  value = aws_security_group.nodes.id
}
