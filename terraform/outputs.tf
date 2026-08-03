output "s3_raw_bucket" {
  description = "Nazwa bucketa raw (landing zone)"
  value       = aws_s3_bucket.raw.id
}

output "s3_processed_bucket" {
  description = "Nazwa bucketa processed"
  value       = aws_s3_bucket.processed.id
}

output "s3_curated_bucket" {
  description = "Nazwa bucketa curated"
  value       = aws_s3_bucket.curated.id
}

output "rds_endpoint" {
  description = "Endpoint RDS PostgreSQL (host:port)"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_db_name" {
  description = "Nazwa bazy danych na RDS"
  value       = aws_db_instance.postgres.db_name
}

output "rds_security_group_id" {
  description = "ID Security Group dla RDS"
  value       = aws_security_group.rds.id
}

output "rds_replica_endpoint" {
  description = "Endpoint Read Replica (tylko prod)"
  value       = var.env == "prod" ? aws_db_instance.postgres_replica[0].endpoint : "N/A (dev)"
  sensitive   = true
}


output "orders_etl_job_name" {
  description = "Nazwa Glue Joba orders - uzywana przez Airflow w M4"
  value       = module.orders_etl.job_name
}

#
# WYNIK `terraform output orders_etl_job_name` (Zajecia 3, Zadanie 3)
#
# orders_etl_job_name = "orders-etl-job"
#
