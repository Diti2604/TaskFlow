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
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  tags = {
    Name = "database-1"
  }
}


resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow inbound traffic to the RDS instance"
  vpc_id      = aws_vpc.my-vpc.id
  
  lifecycle {
    ignore_changes = [ingress, egress]
  }
}


data "aws_secretsmanager_secret_version" "db_master" {
  secret_id  = aws_db_instance.database-1.master_user_secret[0].secret_arn
  depends_on = [aws_db_instance.database-1]
}

locals {
  rds_secret = jsondecode(data.aws_secretsmanager_secret_version.db_master.secret_string)
  rds_user   = local.rds_secret.username
  rds_pass   = local.rds_secret.password
}



                     