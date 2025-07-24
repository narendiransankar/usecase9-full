
# S3 backend and providers configured in providers.tf (not repeated here)

module "vpc" {
  source           = "./modules/vpc"
  vpc_cidr         = "10.0.0.0/16"
  azs              = []  # will default to first 2 AZs if empty
  cluster_name     = var.cluster_name         # for tagging
  env              = var.environment
}

module "ecr" {
  source = "./modules/ecr"
  name   = "api-flask-repo"
}

module "eks" {
  source            = "./modules/eks"
  cluster_name      = var.cluster_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets
  node_instance_type = "t3.small"
  desired_capacity   = 2
  max_capacity       = 3
  min_capacity       = 1
  enable_cluster_logs = true
  # We could pass environment for naming, but cluster_name already unique
  depends_on = [ module.ecr ] 
  # (ensures ECR exists before EKS if needed, though not strictly required for cluster creation)
}

# If using IRSA for ALB, get OIDC provider from cluster
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}
data "aws_iam_openid_connect_provider" "oidc" {
  # The OIDC provider is typically created automatically for EKS (if you enable IAM Roles for Service Accounts).
  # Alternatively, you may create it manually.
  # Here, attempt to fetch by the issuer URL from the cluster:
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  # Note: may need to trim URL path as required by data source. This is a conceptual example.
}

module "monitoring" {
  source        = "./modules/monitoring"
  cluster_name  = module.eks.cluster_name
  cluster_oidc_provider_arn    = data.aws_iam_openid_connect_provider.oidc.arn
  cluster_oidc_provider_id     = data.aws_iam_openid_connect_provider.oidc.id
  vpc_id        = module.vpc.vpc_id
  aws_region    = var.aws_region
  depends_on    = [ module.eks ]  # ensure cluster is up

  # If needed, pass OIDC provider info:
  # cluster_oidc_provider_arn = data.aws_iam_openid_connect_provider.oidc.arn
  # cluster_oidc_provider_id  = data.aws_iam_openid_connect_provider.oidc.id
}

module "iam" {
  source = "./modules/iam"

  # Allow your GitHub repo(s). Adjust the globs to match your organization and repos:
  github_sub_regex = [
    "repo:narendiransankar/usecase9-full:*",   # all branches in that repo
  ]
  # Use the well-known GitHub Actions thumbprint:
  oidc_thumbprint = "2B18947A6A9FC7764FD8B5FB18A863B0C6DAC24F"

  role_name = "oidc_role"
}