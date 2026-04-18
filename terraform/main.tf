locals {
  name        = "url-shortener"
  app_port    = 3000
  aws_region  = "us-east-1"
}

###############################################################
# 1. VPC & NETWORKING
###############################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true   # cost-optimal for this project
  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_group = true

  tags = {
    Project = local.name
  }
}

###############################################################
# 2. SECURITY GROUPS
###############################################################

# ALB — accepts HTTP from internet
resource "aws_security_group" "alb_sg" {
  name   = "${local.name}-alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-alb-sg" }
}

# ECS tasks — only accepts traffic FROM the ALB SG on app port
resource "aws_security_group" "ecs_tasks_sg" {
  name   = "${local.name}-ecs-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = local.app_port
    to_port         = local.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]  # ALB only — not 0.0.0.0/0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-ecs-sg" }
}

# RDS — only accepts traffic FROM the ECS SG on 5432
resource "aws_security_group" "rds_sg" {
  name   = "${local.name}-rds-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-rds-sg" }
}

###############################################################
# 3. ECR REPOSITORY
###############################################################
resource "aws_ecr_repository" "app" {
  name                 = "${local.name}-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${local.name}-ecr" }
}

# Keep only the last 5 images to save storage cost
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

###############################################################
# 4. RDS POSTGRESQL (MULTI-AZ)
###############################################################
resource "aws_db_subnet_group" "rds" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = { Name = "${local.name}-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier           = "${local.name}-db"
  allocated_storage    = 20
  db_name              = var.postgres_db
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  username             = var.postgres_user
  password             = var.postgres_password
  skip_final_snapshot  = true
  multi_az             = true   # standby replica in AZ-1b automatically
  storage_encrypted    = true

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = { Name = "${local.name}-rds" }
}

###############################################################
# 5. APPLICATION LOAD BALANCER
###############################################################
resource "aws_lb" "app" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets   # ALB lives in public subnets

  tags = { Name = "${local.name}-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name}-tg"
  port        = local.app_port   # must match container port — 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"             # required for Fargate

  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = { Name = "${local.name}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

###############################################################
# 6. CLOUDWATCH LOG GROUP
###############################################################
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7

  tags = { Name = "${local.name}-logs" }
}

###############################################################
# 7. IAM — ECS TASK EXECUTION ROLE
###############################################################
data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = { Name = "${local.name}-ecs-execution-role" }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow ECS to pull from ECR and write to CloudWatch
resource "aws_iam_role_policy" "ecs_ecr_logs" {
  name = "${local.name}-ecs-ecr-logs"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

###############################################################
# 8. ECS CLUSTER
###############################################################
resource "aws_ecs_cluster" "app" {
  name = "${local.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"   # enables container-level metrics in CloudWatch
  }

  tags = { Name = "${local.name}-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "app" {
  cluster_name       = aws_ecs_cluster.app.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

###############################################################
# 9. ECS TASK DEFINITION
###############################################################
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"    # 0.5 vCPU
  memory                   = "1024"   # 1 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = local.name
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = local.app_port   # 3000 — matches ALB TG and ECS SG
          hostPort      = local.app_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "NODE_ENV",  value = "production" },
        { name = "PORT",      value = tostring(local.app_port) },
        { name = "LOG_LEVEL", value = "info" }
      ]

      # Sensitive values come from variables — not hardcoded
      secrets = []

      # All DB env vars passed directly (use SSM/Secrets Manager for prod hardening)
      environment = [
        { name = "NODE_ENV",           value = "production" },
        { name = "PORT",               value = tostring(local.app_port) },
        { name = "LOG_LEVEL",          value = "info" },
        { name = "POSTGRES_HOST",      value = aws_db_instance.postgres.address },
        { name = "POSTGRES_USER",      value = var.postgres_user },
        { name = "POSTGRES_PASSWORD",  value = var.postgres_password },
        { name = "POSTGRES_DB",        value = var.postgres_db },
        { name = "DATABASE_URL",       value = "postgresql://${var.postgres_user}:${var.postgres_password}@${aws_db_instance.postgres.address}:5432/${var.postgres_db}" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = local.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:${local.app_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = { Name = "${local.name}-task" }
}

###############################################################
# 10. ECS SERVICE
###############################################################
resource "aws_ecs_service" "app" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2   # one per AZ minimum
  launch_type     = "FARGATE"

  # Force new deployment on every terraform apply
  force_new_deployment = true

  network_configuration {
    subnets          = module.vpc.private_subnets   # tasks run in private subnets
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false   # private subnet + NAT — no public IP needed
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.name
    container_port   = local.app_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true   # auto-rollback if new tasks fail health checks
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_execution_policy,
  ]

  tags = { Name = "${local.name}-service" }
}

###############################################################
# 11. AUTO SCALING
###############################################################
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.app.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale out when CPU > 60%
resource "aws_appautoscaling_policy" "cpu_scale_out" {
  name               = "${local.name}-cpu-scale-out"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60.0
    scale_in_cooldown  = 300   # wait 5 min before scaling in (avoids thrashing)
    scale_out_cooldown = 60    # scale out fast when load spikes
  }
}

# Scale on ALB request count per target (handles 5k → 20k traffic spikes)
resource "aws_appautoscaling_policy" "alb_requests" {
  name               = "${local.name}-alb-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.app.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value       = 500   # scale when any task gets >500 req/s
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

###############################################################
# 12. CLOUDWATCH ALARMS
###############################################################

# High CPU alarm
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${local.name}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU above 80%"

  dimensions = {
    ClusterName = aws_ecs_cluster.app.name
    ServiceName = aws_ecs_service.app.name
  }
}

# ALB 5xx errors alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB getting 5xx errors from ECS"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }
}

# RDS connections alarm
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${local.name}-rds-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS connection count high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }
}
