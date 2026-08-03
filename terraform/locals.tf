locals {
  # Spójny prefix nazewnictwa — używany wszędzie
  name_prefix = "${var.project}-${var.env}"

  # Tagi przypisywane do wszystkich zasobów automatycznie
  common_tags = {
    Project     = var.project
    Environment = var.env
    ManagedBy   = "terraform"
    Owner       = "data-engineering"
    CostCenter  = "data-platform"
  }

  # Konfiguracja zależna od środowiska
  environment_config = {
    dev = {
      rds_instance_class    = "db.t3.micro"
      rds_allocated_storage = 20
      rds_backup_retention  = 1
      s3_lifecycle_days     = 30
    }
    prod = {
      rds_instance_class    = "db.t3.small"
      rds_allocated_storage = 100
      rds_backup_retention  = 7
      s3_lifecycle_days     = 90
    }
  }

  # Aktualnie używana konfiguracja — wybierana na podstawie var.env
  env_config = local.environment_config[var.env]
}
