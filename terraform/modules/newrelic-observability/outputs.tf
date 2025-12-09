output "dashboard_url" {
  description = "URL do Dashboard do New Relic"
  value       = "https://one.newrelic.com/dashboards/${newrelic_one_dashboard.workshop_overview.guid}"
}

output "alert_policy_id" {
  description = "ID da política de alertas"
  value       = newrelic_alert_policy.workshop_alerts.id
}

output "alert_policy_name" {
  description = "Nome da política de alertas"
  value       = newrelic_alert_policy.workshop_alerts.name
}
