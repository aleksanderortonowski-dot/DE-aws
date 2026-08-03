# Upload skryptu ETL do S3 (etag = re-upload tylko gdy zmieni sie plik)
resource "aws_s3_object" "orders_etl_script" {
  bucket = aws_s3_bucket.raw.id
  key    = "glue_scripts/orders_etl.py"
  source = "${path.module}/../glue_scripts/orders_etl.py"
  etag   = filemd5("${path.module}/../glue_scripts/orders_etl.py")
}

# Instancja modulu dla pipeline'u zamowien
module "orders_etl" {
  source = "./modules/glue_job"

  name           = "orders"
  scripts_bucket = aws_s3_bucket.raw.id
  source_bucket  = aws_s3_bucket.raw.id
  target_bucket  = aws_s3_bucket.processed.id
  glue_role_arn  = "" # modul tworzy role automatycznie

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout_minutes   = 60
  max_retries       = 1

  schedule_expression = "cron(0 6 * * ? *)" # 06:00 UTC kazdego dnia

  tags = local.common_tags

  # Glue Job musi miec dostepny skrypt zanim zostanie stworzony
  depends_on = [aws_s3_object.orders_etl_script]
}

#
# WYNIK `terraform plan -var="env=dev"` (Zajecia 3, Zadanie 2)
#
#   # module.orders_etl.aws_glue_trigger.schedule[0] will be created
#   + resource "aws_glue_trigger" "schedule" {
#       + name     = "orders-etl-trigger"
#       + schedule = "cron(0 6 * * ? *)"
#       + type     = "SCHEDULED"
#       + actions { + job_name = "orders-etl-job" }
#     }
#
#   Plan: 11 to add, 0 to change, 0 to destroy.
#
#
