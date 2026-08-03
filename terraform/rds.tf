# Security Group: port 5432 tylko z VPC
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "PostgreSQL accessible only from VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-rds-sg" }
}

# Subnet Group dla RDS (prywatne podsieci)
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${local.name_prefix}-db-subnet-group" }
}

# Parameter Group PostgreSQL — logowanie wolnych zapytań
resource "aws_db_parameter_group" "postgres" {
  name   = "${local.name_prefix}-postgres-params"
  family = "postgres15"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # loguj zapytania trwające ponad 1 sekundę
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = { Name = "${local.name_prefix}-postgres-params" }
}

# RDS PostgreSQL — ta sama baza co w M1, provisowana kodem
resource "aws_db_instance" "postgres" {
  identifier = "${local.name_prefix}-postgres"

  engine                = "postgres"
  engine_version        = "15.13"
  instance_class        = local.env_config.rds_instance_class
  allocated_storage     = local.env_config.rds_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "ecommerce"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.postgres.name

  backup_retention_period = local.env_config.rds_backup_retention
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  publicly_accessible     = false

  # Ochrona przed przypadkowym usunięciem — true tylko na prod
  deletion_protection       = var.env == "prod" ? true : false
  skip_final_snapshot       = var.env == "prod" ? false : true
  final_snapshot_identifier = "${local.name_prefix}-final-snapshot"

  tags = { Name = "${local.name_prefix}-postgres" }
}

# Read Replica — tylko dla prod
resource "aws_db_instance" "postgres_replica" {
  count = var.env == "prod" ? 1 : 0

  identifier          = "${local.name_prefix}-postgres-replica"
  replicate_source_db = aws_db_instance.postgres.identifier

  instance_class       = "db.t3.micro"
  storage_encrypted    = true
  publicly_accessible  = false

  # Replika nie ma własnego backup — replikuje z primary
  backup_retention_period = 0
  skip_final_snapshot     = true

  tags = { Name = "${local.name_prefix}-postgres-replica" }
}

#
# WYNIK `terraform plan -var="env=dev"` (Zadanie 1)
#
#   # aws_db_parameter_group.postgres will be created
#   + resource "aws_db_parameter_group" "postgres" {
#       + family = "postgres15"
#       + name   = "kurs-de-aleksander-ortonowski-dev-postgres-params"
#       ...
#     }
#   # aws_db_instance.postgres will be created
#       + parameter_group_name = "kurs-de-aleksander-ortonowski-dev-postgres-params"
#
#   Plan: 18 to add, 0 to change, 0 to destroy.
#


