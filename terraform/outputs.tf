# 1. The ECR Repository URL (Where your Docker image goes)
output "ecr_repository_url" {
  description = "Copy this to your GitHub Secret: ECR_REPOSITORY_URL"
  value       = aws_ecr_repository.app.repository_url
}

# 2. The RDS Endpoint (Where your Node.js/Python app connects to the DB)
output "rds_address" {
  description = "The hostname of your database"
  value       = aws_db_instance.default.address
}

# 3. The VPC ID (In case you need to troubleshoot networking)
output "vpc_id" {
  description = "The ID of the VPC created"
  value       = module.vpc.vpc_id
}

# 4. The Private Subnets (Where your Fargate tasks will run)
output "private_subnets" {
  description = "The IDs of the private subnets for ECS"
  value       = module.vpc.private_subnets
}
