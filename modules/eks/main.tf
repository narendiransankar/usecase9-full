# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "eks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  })
  tags = { Name = "${var.cluster_name}-cluster-role" }
}
# Attach required policies to cluster role (EKS Cluster needs this to manage AWS resources)
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}
# (AmazonEKSServicePolicy is optional for new clusters:contentReference[oaicite:12]{index=12}, but attached here for completeness)

# IAM Role for EKS Worker Nodes (Node Group)
resource "aws_iam_role" "eks_node" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  })
  tags = { Name = "${var.cluster_name}-node-role" }
}
# Attach AWS-managed policies to node role for EKS workers:contentReference[oaicite:13]{index=13}:
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"  # allow pulling images from ECR
}
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
# Optionally attach CloudWatch agent server policy if we plan to push node logs/metrics to CloudWatch
resource "aws_iam_role_policy_attachment" "node_CloudWatchAgentServerPolicy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Security Group for EKS cluster and nodes
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane communication"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-cluster-sg" }
}
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.cluster_name}-nodes-sg" }
}
# Allow nodes to receive traffic from control plane and ALB (if any) on required ports.
# EKS control plane communicates with nodes on port 443 (kubelet API) and other ports; allow cluster SG -> nodes SG.
resource "aws_security_group_rule" "node_allow_cluster" {
  description       = "Allow cluster SG to communicate with nodes"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.cluster.id
}
# Allow all traffic within node SG (nodes to nodes communication if needed)
resource "aws_security_group_rule" "node_allow_self" {
  description       = "Allow nodes to communicate among themselves"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.nodes.id
}
# Egress rules (defaults allow all outbound)
resource "aws_security_group_rule" "cluster_egress_all" {
  security_group_id = aws_security_group.cluster.id
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "nodes_egress_all" {
  security_group_id = aws_security_group.nodes.id
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

# EKS Cluster
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  # Subnets for EKS to attach network interfaces (typically private subnets recommended)
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.cluster.id]  # control plane SG
    endpoint_public_access = true   # API server accessible publicly (can restrict by CIDR if needed)
    endpoint_private_access = true  # also allow private access within VPC
  }


  # Enable control‐plane logs in CloudWatch:
  enabled_cluster_log_types = var.enable_cluster_logs ? [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ] : []  # use `enabled_cluster_log_types` instead of a dynamic logging block :contentReference[oaicite:0]{index=0}


  # Ensure the cluster creation happens after VPC is ready
  #depends_on = [ aws_internet_gateway.igw ]
}
# Note: aws_eks_cluster will automatically create an EKS-managed security group for the cluster control plane 
# if none is provided. Here we provided our own cluster SG for control plane ENIs for clarity and control.

# EKS Node Group (Managed)
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]
  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_capacity
    min_size     = var.min_capacity
  }
  capacity_type = "ON_DEMAND"
  ami_type      = "AL2_x86_64"  # Amazon Linux 2 (EKS optimized AMI)
  disk_size     = 20           # 20 GB disk
  
  remote_access {
    #ec2_ssh_key = var.ssh_key_name  # optional: if we want SSH access for troubleshooting
    #source_security_groups = []     # could specify allowed SG for SSH
  }
  update_config {
    max_unavailable = 1
  }
  tags = {
    Name = "${var.cluster_name}-node-group"
  }
  depends_on = [aws_eks_cluster.this]  # ensure cluster is created first
}
