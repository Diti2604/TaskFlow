# ============= ECS CLUSTER =============
# Amazon ECS cluster for running Fargate tasks
# No control plane fees (unlike EKS $73/month)

resource "aws_ecs_cluster" "main" {
  name = "taskflow-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"  # Disable to save costs
  }

  tags = {
    Name        = "taskflow-ecs-cluster"
    Environment = "production"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"  # Use SPOT for cost savings
    weight            = 100
    base              = 1
  }
}

# ============= CLOUDWATCH LOG GROUP =============
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/taskflow-api"
  retention_in_days = 7  # Keep logs for 7 days only

  tags = {
    Name = "ecs-taskflow-logs"
  }
}

# ============= ECS TASK EXECUTION ROLE =============
# This role is used by ECS to pull images from ECR and write logs

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ============= ECS TASK ROLE =============
# This role is used by the running container to access AWS services

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "ecs-task-role"
  }
}

# Allow ECS tasks to access Secrets Manager (for RDS credentials)
resource "aws_iam_role_policy" "ecs_secrets_policy" {
  name = "ecs-secrets-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = data.aws_secretsmanager_secret.db-secret.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.secrets-manager-password.arn
      }
    ]
  })
}

# ============= SECURITY GROUP FOR ECS TASKS =============
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-tasks-sg"
  }
}



# ============= ECS TASK DEFINITION =============
resource "aws_ecs_task_definition" "api" {
  family                   = "taskflow-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"   # 0.25 vCPU
  memory                   = "512"   # 0.5 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "fastapi"
      image     = "${aws_ecr_repository.fastapi-app-repo.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SECRET_NAME"
          value = data.aws_secretsmanager_secret.db-secret.name
        },
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.database-1.address
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "BOOTSTRAP_ON_START"
          value = "true"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "taskflow-api-task"
  }
}

# ============= ALB TARGET GROUP FOR ECS =============
resource "aws_lb_target_group" "ecs_api" {
  name        = "ecs-taskflow-api-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my-vpc.id
  target_type = "ip"  # Required for Fargate

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  deregistration_delay = 30  # Faster deregistration for cost savings

  tags = {
    Name = "ecs-api-target-group"
  }
}

# ============= ECS SERVICE =============
resource "aws_ecs_service" "api" {
  name            = "taskflow-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = 60

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
    base              = 1
  }

  network_configuration {
    subnets          = slice(aws_subnet.private-subnets[*].id, 0, var.private_subnets_count)
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_api.arn
    container_name   = "fastapi"
    container_port   = 8000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Wait for ALB to be ready
  depends_on = [
    aws_lb_listener.https,
    aws_lb_target_group.ecs_api
  ]

  tags = {
    Name = "taskflow-api-service"
  }
}

# ============= OUTPUTS =============
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.api.name
}

output "ecs_task_definition" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.api.arn
}
