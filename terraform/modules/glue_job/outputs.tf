output "job_name" {
  description = "Nazwa Glue Joba (do triggerowania przez Airflow w M4)"
  value       = aws_glue_job.this.name
}

output "job_arn" {
  description = "ARN Glue Joba"
  value       = aws_glue_job.this.arn
}

output "role_arn" {
  description = "ARN roli IAM uzywanej przez joba"
  value       = local.effective_role_arn
}

output "trigger_name" {
  description = "Nazwa Glue Trigger (pusta jesli brak harmonogramu)"
  value       = var.schedule_expression != "" ? aws_glue_trigger.schedule[0].name : ""
}
