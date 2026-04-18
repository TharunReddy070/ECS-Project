output "alb_dns_name" {
  description = "Paste this into your browser to reach the app"
  value       = "http://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  description = "Copy this to your GitHub Secret: ECR_REPOSITORY_URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Copy this to your GitHub Secret: ECS_CLUSTER"
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "Copy this to your GitHub Secret: ECS_SERVICE"
  value       = aws_ecs_service.app.name
}

output "rds_endpoint" {
  description = "RDS hostname (already injected into ECS task env vars)"
  value       = aws_db_instance.postgres.address
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs where ECS tasks run"
  value       = module.vpc.private_subnets
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS container logs"
  value       = aws_cloudwatch_log_group.ecs.name
}
