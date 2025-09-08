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
  # provisioner "local-exec" {
  #   command = "Get-Content -Raw rds_sql_scripts.sql | & \"C:\\Program Files\\MySQL\\MySQL Server 8.0\\bin\\mysql.exe\" -h ${self.address} -u ${self.username} -p${self.password}"
  #   working_dir = path.module
  #   interpreter = ["powershell", "-command"]
  # }
}

# # resource "aws_security_group" "db_init_helper" {
# #   name   = "db-init-helper-sg"
# #   vpc_id = aws_vpc.my-vpc.id

# #   egress {
# #     from_port   = 0
# #     to_port     = 0
# #     protocol    = "-1"
# #     cidr_blocks = ["0.0.0.0/0"] # For VPC endpoints / NAT egress
# #   }

# #   tags = { Name = "db-init-helper-sg" }
# # }

# # # Allow ONLY the helper SG to reach MySQL
# # resource "aws_security_group_rule" "rds_from_helper" {
# #   type                     = "ingress"
# #   from_port                = 3306
# #   to_port                  = 3306
# #   protocol                 = "tcp"
# #   security_group_id        = aws_security_group.rds_sg.id
# #   source_security_group_id = aws_security_group.db_init_helper.id
# #   description              = "MySQL from db-init-helper"
# # }



# resource "aws_security_group" "rds_sg" {
#   name        = "rds-sg"
#   description = "Allow inbound from EC2 for init"
#   vpc_id      = aws_vpc.my-vpc.id

#   ingress {
#     from_port       = 3306
#     to_port         = 3306
#     protocol        = "tcp"
#     security_groups = [aws_security_group.ec2_sg.id]  # From EC2 SG
#     description     = "Allow from temp EC2 for DB init"
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "rds-sg"
#   }
# }

# # data "aws_secretsmanager_secret_version" "db_master" {
# #   secret_id  = aws_db_instance.database-1.master_user_secret[0].secret_arn
# #   depends_on = [aws_db_instance.database-1]
# # }

# # locals {
# #   rds_secret = jsondecode(data.aws_secretsmanager_secret_version.db_master.secret_string)
# #   rds_user   = local.rds_secret.username
# #   rds_pass   = local.rds_secret.password
# # }

# # # resource "null_resource" "db_init" {
# # #   depends_on = [aws_db_instance.database-1]

# # #   provisioner "local-exec" {
# # #     interpreter = ["PowerShell","-Command"]
# # #     command = <<EOT
# # #       $env:MYSQL_PWD = "${local.rds_pass}"
# # #       Get-Content -Raw rds_sql_scripts.sql |
# # #         & "C:\\Program Files\\MySQL\\MySQL Server 8.4\\bin\\mysql.exe" `
# # #           -h ${aws_db_instance.database-1.address} -u "${local.rds_user}" 
# # #       Remove-Item Env:\MYSQL_PWD 
# # #     EOT
# # #   }
# # # }


# # # resource "null_resource" "db_init" {
# # #   depends_on = [aws_db_instance.database-1]

# # #   provisioner "local-exec" {
# # #     command     = "Get-Content -Raw rds_sql_scripts.sql | & \"C:\\Program Files\\MySQL\\MySQL Server 8.4\\bin\\mysql.exe\" -h ${aws_db_instance.database-1.address} -u ${local.rds_user}"

# # #     working_dir = path.module
# # #     interpreter = ["PowerShell", "-Command"]

# # #     environment = {
# # #       MYSQL_PWD = nonsensitive(local.rds_pass)
# # #     }
# # #   }
# # # }

# # data "aws_ssm_parameter" "al2023_latest" {
# #   name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
# # }

# # # Temporary EC2 for SSM tunneling (in public subnet for simplicity)
# # resource "aws_instance" "ssm_tunnel" {
# #   ami           = data.aws_ssm_parameter.al2023_latest.value  # Use latest Amazon Linux 2 AMI (lookup via data source)
# #   instance_type = "t3.micro"
# #   subnet_id     = aws_subnet.public-subnets[0].id  # Public subnet for outbound SSM
# #   vpc_security_group_ids = [aws_security_group.ec2_sg.id]  # Create a basic SG allowing SSM (port 22 not needed)
# #   iam_instance_profile = aws_iam_instance_profile.ssm_role.name  # Role with AmazonSSMManagedInstanceCore policy
# #   associate_public_ip_address = true  # For initial SSM setup if no VPC endpoints
# #   user_data =<<EOF
# #     #!/bin/bash
# #     yum update -y
# #     yum install -y mysql  # MySQL client
# #     EOF
# #   tags = {
# #     Name = "temp-ssm-tunnel-for-rds-init"
# #   }
# #   lifecycle {
# #     prevent_destroy = false
# #   }
# # }

# # Basic SG for the EC2 (allow all outbound; inbound only SSM-managed)
# resource "aws_security_group" "ec2_sg" {
#   name        = "ec2-ssm-sg"
#   description = "Allow SSM access"
#   vpc_id      = aws_vpc.my-vpc.id

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "ec2-ssm-sg"
#   }
# }

# # # IAM role for EC2 SSM (attach AmazonSSMManagedInstanceCore policy)
# # resource "aws_iam_role" "ssm_role" {
# #   name = "ssm-ec2-role"
# #   assume_role_policy = jsonencode({
# #     Version = "2012-10-17"
# #     Statement = [{
# #       Action = "sts:AssumeRole"
# #       Effect = "Allow"
# #       Principal = { Service = "ec2.amazonaws.com" }
# #     }]
# #   })
# # }

# # resource "aws_iam_role_policy_attachment" "ssm_core" {
# #   role       = aws_iam_role.ssm_role.name
# #   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# # }

# # resource "aws_iam_instance_profile" "ssm_role" {
# #   name = "ssm-ec2-profile"
# #   role = aws_iam_role.ssm_role.name
# # }
# # resource "null_resource" "db_init" {
# #   depends_on = [
# #     aws_db_instance.database-1,
# #     data.aws_secretsmanager_secret_version.db_master,
# #     aws_instance.ssm_tunnel
# #   ]

# #   provisioner "local-exec" {
# #     command = <<EOT
# #       # Set password early (for all MySQL commands/tests)
# #       $env:MYSQL_PWD = "${nonsensitive(local.rds_pass)}"
# #       Write-Host "MYSQL_PWD set (sensitive value not logged)."

# #       # Step 1: Wait for EC2 SSM agent to be online (handles boot time)
# #       Write-Host "Polling EC2 SSM status for instance ${aws_instance.ssm_tunnel.id}..."
# #       $ec2Ready = $false
# #       $ec2Timeout = 180  # 3 mins max for EC2
# #       while (-not $ec2Ready -and $ec2Timeout -gt 0) {
# #         try {
# #           $ec2Status = aws ssm describe-instance-information --instance-information-filter-list "Key=InstanceIds,Values=[${aws_instance.ssm_tunnel.id}]" --query "InstanceInformationList[0].PingStatus" --output text 2>$null
# #           if ($ec2Status -eq "Online") {
# #             $ec2Ready = $true
# #             Write-Host "EC2 SSM ready: Online."
# #           } else {
# #             Write-Host "EC2 SSM status: $ec2Status. Retrying in 10s... (remaining: $ec2Timeout s)"
# #             Start-Sleep -Seconds 10
# #             $ec2Timeout -= 10
# #           }
# #         } catch {
# #           Write-Host "Error querying EC2 status: $($_.Exception.Message). Retrying in 10s..."
# #           Start-Sleep -Seconds 10
# #           $ec2Timeout -= 10
# #         }
# #       }
# #       if (-not $ec2Ready) { throw "EC2 SSM not ready after 180s" }

# #       # Step 2: Wait for RDS to be fully available
# #       Write-Host "Polling RDS status for ${aws_db_instance.database-1.identifier}..."
# #       $rdsReady = $false
# #       $rdsTimeout = 600  # 10 mins max for RDS init
# #       while (-not $rdsReady -and $rdsTimeout -gt 0) {
# #         try {
# #           $rdsStatus = aws rds describe-db-instances --db-instance-identifier ${aws_db_instance.database-1.identifier} --query "DBInstances[0].DBInstanceStatus" --output text 2>$null
# #           if ($rdsStatus -eq "available") {
# #             $rdsReady = $true
# #             Write-Host "RDS ready: available."
# #           } else {
# #             Write-Host "RDS status: $rdsStatus. Retrying in 30s... (remaining: $rdsTimeout s)"
# #             Start-Sleep -Seconds 30
# #             $rdsTimeout -= 30
# #           }
# #         } catch {
# #           Write-Host "Error querying RDS status: $($_.Exception.Message). Retrying in 30s..."
# #           Start-Sleep -Seconds 30
# #           $rdsTimeout -= 30
# #         }
# #       }
# #       if (-not $rdsReady) { throw "RDS not available after 600s" }

# #       # Step 3: Start SSM port forwarding tunnel
# #       Write-Host "Starting SSM port forwarding (local 3307 -> EC2 -> RDS:3306)..."
# #       $ssmProcess = Start-Process -FilePath "aws" -ArgumentList @(
# #         "ssm", "start-session",
# #         "--target", "${aws_instance.ssm_tunnel.id}",
# #         "--document-name", "AWS-StartPortForwardingSession",
# #         "--parameters", "portNumber=3306,localPortNumber=3307"
# #       ) -WindowStyle Hidden -PassThru -NoNewWindow -RedirectStandardOutput "ssm_log.txt" -RedirectStandardError "ssm_err.txt"

# #       $SSM_PID = $ssmProcess.Id
# #       Write-Host "SSM tunnel started with PID: $SSM_PID. Logs: ssm_log.txt / ssm_err.txt"

# #       # Step 4: Wait for tunnel connectivity with retries
# #       Write-Host "Testing tunnel connection (localhost:3307)..."
# #       $timeout = 300  # 5 mins for tunnel setup
# #       $connected = $false
# #       while (-not $connected -and $timeout -gt 0) {
# #         try {
# #           & "C:\\Program Files\\MySQL\\MySQL Server 8.4\\bin\\mysql.exe" -h 127.0.0.1 -P 3307 -u "${local.rds_user}" -e "SELECT 1;" --connect-timeout=10 --silent
# #           $connected = $true
# #           Write-Host "Tunnel connected successfully."
# #         } catch {
# #           $errMsg = $_.Exception.Message
# #           Write-Host "Tunnel test failed: $errMsg. Retrying in 5s... (remaining: $timeout s)"
# #           # Optional: Check local port open? netstat -an | find "3307" (but keep simple)
# #           Start-Sleep -Seconds 5
# #           $timeout -= 5
# #         }
# #       }
# #       if (-not $connected) { 
# #         # Debug: Dump logs
# #         Get-Content ssm_log.txt -ErrorAction SilentlyContinue | Write-Host
# #         Get-Content ssm_err.txt -ErrorAction SilentlyContinue | Write-Host
# #         throw "Failed to establish tunnel after 300s. Check SG rules, VPC routing, and ssm_log.txt."
# #       }

# #       # Step 5: Execute the SQL script to create 'users' table
# #       Write-Host "Executing rds_sql_scripts.sql over tunnel..."
# #       Get-Content -Raw rds_sql_scripts.sql | & "C:\\Program Files\\MySQL\\MySQL Server 8.4\\bin\\mysql.exe" -h 127.0.0.1 -P 3307 -u "${local.rds_user}" --silent
# #       Write-Host "SQL script executed successfully."

# #       # Step 6: Cleanup
# #       Write-Host "Cleaning up tunnel (PID: $SSM_PID)..."
# #       Stop-Process -Id $SSM_PID -Force -ErrorAction SilentlyContinue
# #       Remove-Item "ssm_log.txt" -ErrorAction SilentlyContinue
# #       Remove-Item "ssm_err.txt" -ErrorAction SilentlyContinue
# #       Remove-Item Env:\MYSQL_PWD
# #       Write-Host "DB initialization complete. Tunnel closed."
# #     EOT

# #     working_dir = path.module
# #     interpreter = ["PowerShell", "-Command"]
# #   }

# #   triggers = {
# #     db_address = aws_db_instance.database-1.address
# #     db_user    = local.rds_user
# #     instance_id = aws_instance.ssm_tunnel.id
# #   }
# # }
 

# data "aws_ami" "al2023" {
#   most_recent = true
#   owners      = ["amazon"]
#   filter {
#     name   = "name"
#     values = ["al2023-ami-*-x86_64"]
#   }
#   filter {
#     name   = "state"
#     values = ["available"]
#   }
# }
# # SG for the EIC endpoint (egress allowed; no inbound required)
# resource "aws_security_group" "eic_sg" {
#   name        = "eic-endpoint-sg"
#   description = "Security group for EC2 Instance Connect Endpoint"
#   vpc_id      = aws_vpc.my-vpc.id

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = merge(var.tags, { Name = "eic-endpoint-sg" })
# }



# # SG for the private EC2 instance
# resource "aws_security_group" "instance_sg" {
#   name        = "private-bootstrapper-sg"
#   description = "Allows SSH only from EIC endpoint; egress anywhere via NAT"
#   vpc_id      = aws_vpc.my-vpc.id

#   # Ingress SSH ONLY from the EIC endpoint SG
#   ingress {
#     description              = "SSH from EIC endpoint SG"
#     from_port                = 22
#     to_port                  = 22
#     protocol                 = "tcp"
#     security_groups          = [aws_security_group.eic_sg.id]
#   }

#   # Egress anywhere (NAT will handle internet access)
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = merge(var.tags, { Name = "private-bootstrapper-sg" })
# }

# # Allow MySQL 3306 from the instance SG into the existing RDS SG
# resource "aws_security_group_rule" "rds_from_instance" {
#   type                     = "ingress"
#   description              = "MySQL from private bootstrapper instance"
#   from_port                = 3306
#   to_port                  = 3306
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.rds_sg.id
#   source_security_group_id = aws_security_group.instance_sg.id
# }


# resource "aws_iam_role" "ec2_role" {
#   name = "private-bootstrapper-ec2-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect    = "Allow",
#       Principal = { Service = "ec2.amazonaws.com" },
#       Action    = "sts:AssumeRole"
#     }]
#   })
#   tags = var.tags
# }

# resource "aws_iam_policy" "secrets_read" {
#   name   = "private-bootstrapper-secrets-read"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Sid: "ReadDbSecret",
#         Effect: "Allow",
#         Action: [
#           "secretsmanager:GetSecretValue"
#         ],
#         Resource: ["*"]
#       }
#       # NOTE: If your secret uses a customer-managed KMS key,
#       # ensure the key policy allows this role to decrypt.
#       # You typically do NOT need kms:Decrypt here if the key policy trusts your account/role.
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "secrets_read_attach" {
#   role       = aws_iam_role.ec2_role.name
#   policy_arn = aws_iam_policy.secrets_read.arn
# }

# resource "aws_iam_instance_profile" "ec2_profile" {
#   name = "private-bootstrapper-profile"
#   role = aws_iam_role.ec2_role.name
# }


# # User-data script inline; see the rendered script at the bottom of this answer too.
# locals {
#   user_data = <<-EOT
#     #!/bin/bash
#     # Log everything to /var/log/user-data.log
#     exec > >(tee -a /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

#     set -euo pipefail

#     REGION="${var.aws_region}"
#     RDS_ENDPOINT="${aws_db_instance.database-1.address}"
#     DB_USER="${var.db_username}"
#     SECRET_ID="${aws_secretsmanager_secret.rds_secret.id}"

#     if [ -z "$RDS_ENDPOINT" ]; then
#       echo "ERROR: RDS endpoint not provided. Set var.rds_endpoint or var.rds_identifier." >&2
#       exit 1
#     fi

#     echo "[*] Detecting OS and package manager..."
#     PM="dnf"
#     if grep -qi 'Amazon Linux' /etc/os-release; then
#       if grep -q 'VERSION_ID="2"' /etc/os-release; then
#         PM="yum"
#       else
#         PM="dnf"
#       fi
#     fi
#     echo "    -> Using package manager: $PM"

#     retry() {
#       local n=0
#       local max=5
#       local delay=5
#       until "$@"; do
#         n=$((n+1))
#         if [ "$n" -ge "$max" ]; then
#           echo "Command failed after $n attempts: $*" >&2
#           return 1
#         fi
#         echo "Retry $n/$max: $*"
#         sleep "$delay"
#       done
#     }

#     echo "[*] Updating system packages..."
#     retry sudo $PM -y update || true

#     echo "[*] Installing awscli, python3-pip, and MariaDB/MySQL client..."
#     if [ "$PM" = "dnf" ]; then
#       retry sudo dnf -y install awscli python3-pip mariadb105 || true
#     else
#       retry sudo yum -y install awscli python3-pip mariadb || true
#     fi

#     echo "[*] Installing Python packages..."
#     retry sudo pip3 install --upgrade pip
#     retry sudo pip3 install fastapi uvicorn pymysql

#     echo "[*] Fetching DB password from Secrets Manager..."
#     SECRET_JSON=$(aws --region "$REGION" secretsmanager get-secret-value --secret-id "$SECRET_ID" --query SecretString --output text)
#     DB_PASS=$(python3 - <<'PY'
# import json, os, sys
# s = os.environ.get("SECRET_JSON","")
# try:
#     print(json.loads(s)["password"])
# except Exception as e:
#     print("", end="")
#     sys.exit(1)
# PY
# )
#     if [ -z "$DB_PASS" ]; then
#       echo "ERROR: Could not parse 'password' from secret ${data.aws_secretsmanager_secret.rds_master.arn}" >&2
#       exit 1
#     fi
#     echo "    -> Got DB password from secret."

#     echo "[*] Waiting for MySQL to accept connections at ${aws_db_instance.database-1.address}..."
#     for i in $(seq 1 40); do
#       if mysqladmin --connect-timeout=5 ping -h "${aws_db_instance.database-1.address}" --silent; then
#         echo "    -> MySQL is ready."
#         break
#       fi
#       echo "    -> Attempt $i/40: still waiting..."
#       sleep 15
#     done

#     if ! mysqladmin --connect-timeout=5 ping -h "${aws_db_instance.database-1.address}" --silent; then
#       echo "ERROR: Timed out waiting for MySQL at ${aws_db_instance.database-1.address}" >&2
#       exit 1
#     fi

#     echo "[*] Running idempotent SQL..."
#     mysql -h "${aws_db_instance.database-1.address}" -u "$DB_USER" -p"$DB_PASS" -e "
#       CREATE DATABASE IF NOT EXISTS database_1;
#       CREATE TABLE IF NOT EXISTS database_1.users (
#         id INT AUTO_INCREMENT PRIMARY KEY,
#         name VARCHAR(255) NOT NULL,
#         password VARCHAR(255) NOT NULL
#       );
#     "

#     echo "[*] Bootstrap complete."
#   EOT
# }


# resource "aws_instance" "db_bootstrapper" {
#   ami                         = data.aws_ami.al2023.id
#   instance_type               = var.instance_type
#   subnet_id                   = aws_subnet.private-subnets[1].id
#   vpc_security_group_ids      = [aws_security_group.instance_sg.id]
#   associate_public_ip_address = false
#   iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

#   # Optional SSH key (EIC works with/without a traditional keypair)
#   key_name = aws_key_pair.my_key.key_name

#   user_data                   = local.user_data
#   user_data_replace_on_change = true

#   tags = merge(var.tags, { Name = "private-db-bootstrapper" })
# }