########################################
# 3. Outputs
########################################
output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN of the GitHub Actions OIDC provider"
}

output "oidc_role_arn" {
  value       = aws_iam_role.oidc_role.arn
  description = "ARN of the IAM role for GitHub Actions OIDC"
}