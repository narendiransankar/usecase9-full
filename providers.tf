# Terraform Block
terraform {
  #required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}
provider "aws" {
  region  = var.aws_region
  #profile = "devops"
}

# Data sources to retrieve EKS cluster info for Kubernetes provider
data "aws_eks_cluster" "eks" {
  name = module.eks.cluster_name
}
data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
}

# Kubernetes provider uses cluster details (with short-lived token via aws_eks_cluster_auth)
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
  #load_config_file       = false
  # If needed, you could use exec auth or kubeconfig file. Here we use token for simplicity.
}

provider "helm" {
  # Helm provider will use the same config as Kubernetes provider (could also specify kubeconfig)
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}
