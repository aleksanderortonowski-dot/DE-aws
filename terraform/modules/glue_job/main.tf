# -- IAM Role - tworzona tylko gdy nie podano zewnetrznej --
resource "aws_iam_role" "glue" {
  count = var.glue_role_arn == "" ? 1 : 0
  name  = "glue-${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  count      = var.glue_role_arn == "" ? 1 : 0
  role       = aws_iam_role.glue[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  count = var.glue_role_arn == "" ? 1 : 0
  name  = "glue-${var.name}-s3"
  role  = aws_iam_role.glue[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.source_bucket}",
          "arn:aws:s3:::${var.source_bucket}/*",
          "arn:aws:s3:::${var.scripts_bucket}",
          "arn:aws:s3:::${var.scripts_bucket}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${var.target_bucket}",
          "arn:aws:s3:::${var.target_bucket}/*",
        ]
      }
    ]
  })
}


locals {
  effective_role_arn = var.glue_role_arn != "" ? var.glue_role_arn : aws_iam_role.glue[0].arn
}

# -- Glue Job --
resource "aws_glue_job" "this" {
  name     = "${var.name}-etl-job"
  role_arn = local.effective_role_arn

  command {
    name            = "glueetl"
    script_location = "s3://${var.scripts_bucket}/glue_scripts/${var.name}_etl.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = ""
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${var.scripts_bucket}/spark-logs/${var.name}/"
    "--enable-job-insights"              = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--SOURCE_BUCKET"                    = var.source_bucket
    "--TARGET_BUCKET"                    = var.target_bucket
    "--TempDir"                          = "s3://${var.scripts_bucket}/tmp/${var.name}/"
  }

  glue_version      = var.glue_version
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.timeout_minutes
  max_retries       = var.max_retries

  tags = var.tags
}

resource "aws_glue_trigger" "schedule" {
  count = var.schedule_expression != "" ? 1 : 0

  name     = "${var.name}-etl-trigger"
  type     = "SCHEDULED"
  schedule = var.schedule_expression

  enabled = false

  actions {
    job_name = aws_glue_job.this.name
  }

  tags = var.tags
}
