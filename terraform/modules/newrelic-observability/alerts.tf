# Alert Policy: Smart Mechanical Workshop
resource "newrelic_alert_policy" "workshop_alerts" {
  name                = "Smart Mechanical Workshop - Alerts"
  incident_preference = "PER_CONDITION"
}

# Notification Channel: Email
resource "newrelic_notification_destination" "email" {
  name = "Workshop Team Email"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.alert_email
  }
}

resource "newrelic_notification_channel" "email_channel" {
  name           = "Workshop Alerts Email"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "New Relic Alert: {{issueTitle}}"
  }
}

resource "newrelic_workflow" "workshop_workflow" {
  name                  = "Workshop Alert Workflow"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "Filter by policy"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.workshop_alerts.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email_channel.id
  }
}

# Alert: Alta Latência nas APIs
resource "newrelic_nrql_alert_condition" "high_api_latency" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.workshop_alerts.id
  type                         = "static"
  name                         = "Alta Latência nas APIs (p95 > 2s)"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = <<-NRQL
      SELECT percentile(duration, 95) 
      FROM Transaction 
      WHERE appName = '${var.app_name}'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 2.0
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 1.5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# Alert: Alta Taxa de Erro
resource "newrelic_nrql_alert_condition" "high_error_rate" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.workshop_alerts.id
  type                         = "static"
  name                         = "Alta Taxa de Erro (> 5%)"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = <<-NRQL
      SELECT percentage(count(*), WHERE error IS true) 
      FROM Transaction 
      WHERE appName = '${var.app_name}'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 5.0
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 2.0
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# Alert: Falhas no Processamento de Ordens de Serviço
resource "newrelic_nrql_alert_condition" "service_order_failures" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.workshop_alerts.id
  type                         = "static"
  name                         = "Falhas no Processamento de Ordens"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = <<-NRQL
      SELECT count(*) 
      FROM TransactionError 
      WHERE appName = '${var.app_name}' 
      AND `error.class` LIKE '%ServiceOrder%'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 10
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# Alert: Health Check Failing
resource "newrelic_nrql_alert_condition" "health_check_down" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.workshop_alerts.id
  type                         = "static"
  name                         = "Health Check Failing"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = <<-NRQL
      SELECT percentage(count(*), WHERE httpResponseCode != 200) 
      FROM Transaction 
      WHERE appName = '${var.app_name}' 
      AND request.uri = '/health'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 50
    threshold_duration    = 180
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# Alert: Alto Consumo de CPU no Kubernetes
resource "newrelic_nrql_alert_condition" "high_cpu_usage" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.workshop_alerts.id
  type                         = "static"
  name                         = "Alto Consumo de CPU no K8s (> 80%)"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = <<-NRQL
      SELECT average(cpuUsedCores / cpuLimitCores * 100) 
      FROM K8sPodSample 
      WHERE clusterName = 'smart-workshop-eks-cluster' 
      AND namespaceName = 'smart-workshop'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 80
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 70
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# Alert: Alto Consumo de Memória no Kubernetes
resource "newrelic_nrql_alert_condition" "high_memory_usage" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.workshop_alerts.id
  type                         = "static"
  name                         = "Alto Consumo de Memória no K8s (> 85%)"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = <<-NRQL
      SELECT average(memoryUsedBytes / memoryLimitBytes * 100) 
      FROM K8sPodSample 
      WHERE clusterName = 'smart-workshop-eks-cluster' 
      AND namespaceName = 'smart-workshop'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 85
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  warning {
    operator              = "above"
    threshold             = 75
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# Alert: Pod Restart Loops
resource "newrelic_nrql_alert_condition" "pod_restart_loops" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.workshop_alerts.id
  type                         = "static"
  name                         = "Pod Restart Loops Detectado"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = <<-NRQL
      SELECT sum(restartCount) 
      FROM K8sContainerSample 
      WHERE clusterName = 'smart-workshop-eks-cluster' 
      AND namespaceName = 'smart-workshop'
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# Alert: Baixo Throughput (possível problema)
resource "newrelic_nrql_alert_condition" "low_throughput" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.workshop_alerts.id
  type                         = "static"
  name                         = "Throughput Anormalmente Baixo"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = <<-NRQL
      SELECT rate(count(*), 1 minute) 
      FROM Transaction 
      WHERE appName = '${var.app_name}'
    NRQL
  }

  critical {
    operator              = "below"
    threshold             = 1
    threshold_duration    = 600
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}

# Alert: Database Connection Issues
resource "newrelic_nrql_alert_condition" "database_errors" {
  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.workshop_alerts.id
  type                         = "static"
  name                         = "Erros de Conexão com Banco de Dados"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = <<-NRQL
      SELECT count(*) 
      FROM TransactionError 
      WHERE appName = '${var.app_name}' 
      AND (`error.message` LIKE '%database%' OR `error.message` LIKE '%connection%' OR `error.message` LIKE '%timeout%')
    NRQL
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option        = "none"
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 120
}
