resource "aws_db_subnet_group" "db-subnet-group" {
  name       = var.db_subnet_group_name
  subnet_ids = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count)
  tags = {
    Name = var.db_subnet_group_name
  }
}

resource "aws_db_instance" "database-1" {
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
  depends_on = [ aws_vpc.my-vpc ]

}