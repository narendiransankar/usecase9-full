resource "aws_ecr_repository" "this" {
  name                 = var.name   # repository name, e.g., "api-flask-repo"
  image_scanning_configuration {
    scan_on_push = true  # enable vulnerability scanning on image push
  }
  image_tag_mutability = "MUTABLE"
  tags = {
    Name = var.name
  }
}
