# (Ensure this module is invoked after cluster is created; dependency handled in root configuration via module dependencies or Terraform graph)

# Create a namespace for monitoring components
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Deploy kube-prometheus-stack (Prometheus & Grafana) via Helm chart
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prom-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "51.2.0"             # example version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  create_namespace = false          # namespace is created above
  values = [<<EOF
    grafana:
      adminPassword: "Admin@1234"   # example password, should come from secret in real config
      service:
        type: ClusterIP
    alertmanager:
      enabled: true
    prometheus:
      prometheusSpec:
        serviceMonitorSelector: {}
        podMonitorSelector: {}
  EOF
  ]
}

# (Optional) Deploy AWS Load Balancer Controller via Helm (for Ingress)
resource "kubernetes_namespace" "alb_system" {
  metadata { name = "aws-load-balancer" }
}
# Create an IAM role for the ALB controller service account (IRSA)
data "aws_iam_policy_document" "alb_irsa_assume" {
  statement {
    effect = "Allow"
    principals {
      type = "Federated"
      identifiers = [var.cluster_oidc_provider_arn]  # OIDC provider ARN for the cluster
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test = "StringEquals"
      values = ["aws-load-balancer-controller"]
      variable = "${var.cluster_oidc_provider_id}:sub"
      # ^ The above would be something like "oidc.eks.region.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E:sub"
    }
  }
}
resource "aws_iam_role" "alb_controller" {
  name = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_irsa_assume.json
}
# Attach AWS-managed policy for ALB controller 
resource "aws_iam_role_policy_attachment" "alb_controller_policy" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy" 
  # This policy ARN is assumed to exist if we created it (AWS provides a downloadable policy JSON for ALB Controller).
  # Alternatively, attach necessary permissions inline or via file.
}
# Create ServiceAccount for ALB controller with IRSA annotation
resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = kubernetes_namespace.alb_system.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }
}
# Install the AWS Load Balancer Controller via Helm
resource "helm_release" "aws_load_balancer_controller" {
  name        = "aws-load-balancer-controller"
  repository  = "https://aws.github.io/eks-charts"
  chart       = "aws-load-balancer-controller"
  version     = "1.5.3"  # example version
  namespace   = kubernetes_namespace.alb_system.metadata[0].name
  create_namespace = false
  depends_on  = [ kubernetes_service_account.alb_sa ]  # ensure SA is ready with IAM role
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_sa.metadata[0].name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
}
