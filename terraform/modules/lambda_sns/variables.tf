variable "name_prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "alert_email" {
  description = "Email address for SNS alert"
  type        = string
}
