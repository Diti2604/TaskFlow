resource "aws_ecr_repository" "fastapi-app-repo" {
  name                 = "fastapi-app"
  image_tag_mutability = "MUTABLE"
  
  force_delete = true
}