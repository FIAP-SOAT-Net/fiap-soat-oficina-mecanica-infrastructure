variable "newrelic_account_id" {
  description = "New Relic Account ID"
  type        = string
}

variable "newrelic_api_key" {
  description = "New Relic User API Key"
  type        = string
  sensitive   = true
}

variable "newrelic_region" {
  description = "New Relic region (US or EU)"
  type        = string
  default     = "US"
}

variable "app_name" {
  description = "Application name in New Relic"
  type        = string
  default     = "smart-mechanical-workshop-api"
}

variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
}

variable "environment" {
  description = "Environment name (production, staging, etc)"
  type        = string
  default     = "production"
}
