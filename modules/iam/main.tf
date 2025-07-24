########################################
# 1. GitHub Actions OIDC Provider
########################################
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.oidc_thumbprint]
  lifecycle {
    prevent_destroy = true
  }
  tags = {
    Name = "GitHub-Actions-OIDC"
  }
}

########################################
# 2. IAM Role for GitHub Actions (OIDC)
########################################
data "aws_iam_policy_document" "oidc_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_sub_regex
    }
  }
}

resource "aws_iam_role" "oidc_role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.oidc_assume.json

  tags = {
    Name = var.role_name
  }
}

# (Optional) Attach any policies necessary for your CI—e.g., full admin or scoped permissions.
resource "aws_iam_role_policy_attachment" "oidc_role_admin" {
  role       = aws_iam_role.oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

