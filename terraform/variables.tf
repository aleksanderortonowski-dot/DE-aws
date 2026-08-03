variable "aws_region" {
  description = "AWS region dla wszystkich zasobów"
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Nazwa projektu używana w nazewnictwie zasobów"
  type        = string
  default     = "ecommerce"
}

variable "env" {
  description = "Środowisko (dev/staging/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env musi być jednym z: dev, staging, prod"
  }
}

variable "db_username" {
  description = "Login do bazy RDS PostgreSQL"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Hasło do bazy RDS PostgreSQL (min. 8 znaków)"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "ID VPC gdzie zostanie wdrożony RDS"
  type        = string
}

variable "private_subnet_ids" {
  description = "Lista ID prywatnych podsieci dla RDS Subnet Group"
  type        = list(string)
}
