# Example: Using New Relic Observability Module
# Add this to your main Terraform configuration

module "newrelic_observability" {
  source = "./modules/newrelic-observability"

  newrelic_account_id = var.newrelic_account_id
  newrelic_api_key    = var.newrelic_api_key
  newrelic_region     = "US" # or "EU"
  
  app_name    = "smart-mechanical-workshop-api"
  alert_email = var.alert_email
  environment = "production"
}

# Required variables
variable "newrelic_account_id" {
  description = "New Relic Account ID"
  type        = string
}

variable "newrelic_api_key" {
  description = "New Relic User API Key"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
}

# Outputs
output "newrelic_dashboard_url" {
  description = "URL do Dashboard do New Relic"
  value       = module.newrelic_observability.dashboard_url
}
