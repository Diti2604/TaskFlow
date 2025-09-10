resource "aws_db_subnet_group" "db-subnet-group" {
  name       = var.db_subnet_group_name
  subnet_ids = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count)
  tags = {
    Name = var.db_subnet_group_name
  }
}

resource "aws_db_instance" "database-1" {
  identifier                    = "database-1"
  allocated_storage             = 10
  db_name                       = var.db_name
  db_subnet_group_name          = aws_db_subnet_group.db-subnet-group.id
  engine                        = "mysql"
  engine_version                = "8.0"
  instance_class                = "db.t3.micro"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.secrets-manager-password.key_id
  username                      = var.db_username
  parameter_group_name          = "default.mysql8.0"
  skip_final_snapshot           = true
  apply_immediately             = true
  depends_on                    = [aws_vpc.my-vpc]
  vpc_security_group_ids = [aws_security_group.rds_mysql.id]
  # provisioner "local-exec" {
  #   command = "Get-Content -Raw rds_sql_scripts.sql | & \"C:\\Program Files\\MySQL\\MySQL Server 8.0\\bin\\mysql.exe\" -h ${self.address} -u ${self.username} -p${self.password}"
  #   working_dir = path.module
  #   interpreter = ["powershell", "-command"]
  # }
}


resource "aws_security_group" "rds_mysql" {
  name        = "rds-mysql-from-private-subnets"
  description = "Allow MySQL from EKS private subnets"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description = "MySQL from private subnets"
    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = [for s in aws_subnet.private-subnets : s.cidr_block]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds-mysql" }
}

# Policy scoped to just your RDS secret
resource "aws_iam_policy" "secrets_read_db" {
  name        = "eks-nodes-read-db-secret"
  description = "Allow nodes to GetSecretValue for the DB secret"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = aws_db_instance.database-1.master_user_secret[0].secret_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_secrets_read_db" {
  role       = aws_iam_role.nodes.name
  policy_arn = aws_iam_policy.secrets_read_db.arn
}
