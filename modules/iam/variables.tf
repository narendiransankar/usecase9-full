variable "github_sub_regex" {
  description = "Allowed GitHub Actions OIDC subjects (e.g. repo:owner/repo:ref)"
  type        = list(string)
}

variable "oidc_thumbprint" {
  description = "40-char SHA1 thumbprint for token.actions.githubusercontent.com"
  type        = string
  default     = "2B18947A6A9FC7764FD8B5FB18A863B0C6DAC24F"
}

variable "role_name" {
  description = "Name of the IAM role to create for OIDC-based access"
  type        = string
  default     = "oidc_role"
}
