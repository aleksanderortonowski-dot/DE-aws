variable "name" {
  description = "Suffix nazwy Glue Joba (np. 'orders', 'customers')"
  type        = string
}

variable "scripts_bucket" {
  description = "Bucket S3 z uploadowanymi skryptami Glue"
  type        = string
}

variable "source_bucket" {
  description = "Bucket S3 z danymi wejściowymi (raw)"
  type        = string
}

variable "target_bucket" {
  description = "Bucket S3 na dane wyjściowe (processed)"
  type        = string
}

variable "glue_role_arn" {
  description = "ARN roli IAM dla Glue. Pusta = moduł tworzy rolę automatycznie"
  type        = string
  default     = ""
}

variable "glue_version" {
  description = "Wersja AWS Glue (4.0 = Spark 3.3, Python 3.10)"
  type        = string
  default     = "4.0"
}

variable "worker_type" {
  description = "Typ workera: G.025X (tani), G.1X (standard), G.2X (duże dane)"
  type        = string
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Liczba workerów Spark"
  type        = number
  default     = 2
}

variable "timeout_minutes" {
  description = "Maksymalny czas wykonania joba w minutach"
  type        = number
  default     = 60
}

variable "max_retries" {
  description = "Liczba prob ponowienia przy bledzie"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tagi przypisywane do wszystkich zasobow modulu"
  type        = map(string)
  default     = {}
}

variable "schedule_expression" {
  description = "Wyrazenie CRON dla harmonogramu Glue Trigger. Puste = brak triggera."
  type        = string
  default     = ""
}
