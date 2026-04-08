locals {
  name = "poc-devops-project"
}

# 1. VPC & Networking
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true 

  create_database_subnet_group = true
}

# 2. Security Groups
resource "aws_security_group" "ecs_tasks" {
  name   = "${local.name}-ecs-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Artifact Storage (ECR)
resource "aws_ecr_repository" "app" {
  name                 = "secure-app-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 4. Database (RDS) - FIXED WITH EXPLICIT SUBNET GROUP
resource "aws_db_subnet_group" "poc_db_subnets" {
  # We use a dynamic name to avoid conflicts with "ghost" groups
  name       = "poc-db-subnet-group-${module.vpc.vpc_id}" 
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "POC DB Subnet Group"
  }
}

resource "aws_db_instance" "default" {
  allocated_storage    = 20
  db_name              = "pocdb"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  username             = "dbadmin"
  password             = "Password123!" 
  skip_final_snapshot  = true

  # Points directly to the resource defined above
  db_subnet_group_name = aws_db_subnet_group.poc_db_subnets.name

  vpc_security_group_ids = [aws_security_group.db_sg.id]
}
