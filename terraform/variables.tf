variable "postgres_user" {
  description = "RDS master username"
  type        = string
  default     = "dbadmin"
}

variable "postgres_password" {
  description = "RDS master password — override via TF_VAR_postgres_password env var or terraform.tfvars"
  type        = string
  sensitive   = true
}

variable "postgres_db" {
  description = "RDS database name"
  type        = string
  default     = "urlshortener"
}
