# Dashboard: Smart Mechanical Workshop - Overview
resource "newrelic_one_dashboard" "workshop_overview" {
  name = "Smart Mechanical Workshop - Overview"

  page {
    name = "Overview"

    # Volume diário de ordens de serviço
    widget_billboard {
      title  = "Volume Diário de Ordens de Serviço"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT count(*) as 'Total de Ordens'
          FROM ServiceOrder
          WHERE action = 'created'
          SINCE today
        NRQL
      }
    }

    # Ordens por Status (hoje)
    widget_pie {
      title  = "Ordens por Status (Hoje)"
      row    = 1
      column = 5
      width  = 4
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT count(*) 
          FROM ServiceOrder 
          WHERE action IN ('created', 'updated')
          FACET status 
          SINCE today
        NRQL
      }
    }

    # Taxa de Erro (últimas 24h)
    widget_billboard {
      title  = "Taxa de Erro (24h)"
      row    = 1
      column = 9
      width  = 4
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT percentage(count(*), WHERE error IS true) as 'Error Rate %'
          FROM Transaction
          WHERE appName = '${var.app_name}'
          SINCE 24 hours ago
        NRQL
      }
    }

    # Latência Média das APIs (p50, p95, p99)
    widget_line {
      title  = "Latência das APIs (ms)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT 
            percentile(duration, 50) as 'p50',
            percentile(duration, 95) as 'p95',
            percentile(duration, 99) as 'p99'
          FROM Transaction
          WHERE appName = '${var.app_name}'
          TIMESERIES AUTO
          SINCE 1 hour ago
        NRQL
      }
    }

    # Throughput (requisições por minuto)
    widget_line {
      title  = "Throughput (req/min)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT rate(count(*), 1 minute) as 'Requests/min'
          FROM Transaction
          WHERE appName = '${var.app_name}'
          TIMESERIES AUTO
          SINCE 1 hour ago
        NRQL
      }
    }
  }

  page {
    name = "Service Orders - Business Metrics"

    # Tempo médio de execução por status (Diagnóstico)
    widget_billboard {
      title  = "Tempo Médio - Diagnóstico (min)"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT average(durationMs) / 60000 as 'Minutos'
          FROM ServiceOrder
          WHERE status IN ('Received', 'UnderDiagnosis', 'WaitingApproval')
          SINCE 7 days ago
        NRQL
      }
    }

    # Tempo médio de execução por status (Execução)
    widget_billboard {
      title  = "Tempo Médio - Execução (min)"
      row    = 1
      column = 5
      width  = 4
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT average(durationMs) / 60000 as 'Minutos'
          FROM ServiceOrder
          WHERE status IN ('InProgress', 'Completed')
          SINCE 7 days ago
        NRQL
      }
    }

    # Tempo médio de execução por status (Finalização)
    widget_billboard {
      title  = "Tempo Médio - Finalização (min)"
      row    = 1
      column = 9
      width  = 4
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT average(durationMs) / 60000 as 'Minutos'
          FROM ServiceOrder
          WHERE status = 'Delivered'
          SINCE 7 days ago
        NRQL
      }
    }

    # Timeline de ordens por status (últimos 7 dias)
    widget_area {
      title  = "Ordens por Status - Últimos 7 Dias"
      row    = 4
      column = 1
      width  = 12
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT count(*)
          FROM ServiceOrder
          FACET status
          TIMESERIES 1 day
          SINCE 7 days ago
        NRQL
      }
    }

    # Distribuição de serviços por ordem
    widget_histogram {
      title  = "Distribuição - Serviços por Ordem"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT histogram(servicesCount, 10, 5)
          FROM ServiceOrder
          WHERE action = 'created'
          SINCE 7 days ago
        NRQL
      }
    }

    # Taxa de conversão (aprovação vs rejeição)
    widget_pie {
      title  = "Taxa de Conversão - Aprovação/Rejeição"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT count(*)
          FROM ServiceOrder
          WHERE status IN ('Rejected', 'Delivered', 'Completed', 'Cancelled')
          FACET status
          SINCE 7 days ago
        NRQL
      }
    }
  }

  page {
    name = "Infrastructure - Kubernetes"

    # CPU Usage por Pod
    widget_line {
      title  = "CPU Usage por Pod (%)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT average(cpuUsedCores / cpuLimitCores * 100) as 'CPU %'
          FROM K8sPodSample
          WHERE clusterName = 'smart-workshop-eks-cluster'
          AND namespaceName = 'smart-workshop'
          FACET podName
          TIMESERIES AUTO
          SINCE 1 hour ago
        NRQL
      }
    }

    # Memory Usage por Pod
    widget_line {
      title  = "Memory Usage por Pod (MB)"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT average(memoryUsedBytes / 1024 / 1024) as 'Memory MB'
          FROM K8sPodSample
          WHERE clusterName = 'smart-workshop-eks-cluster'
          AND namespaceName = 'smart-workshop'
          FACET podName
          TIMESERIES AUTO
          SINCE 1 hour ago
        NRQL
      }
    }

    # Pod Restarts
    widget_billboard {
      title  = "Pod Restarts (última hora)"
      row    = 4
      column = 1
      width  = 4
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT sum(restartCount) as 'Total Restarts'
          FROM K8sContainerSample
          WHERE clusterName = 'smart-workshop-eks-cluster'
          AND namespaceName = 'smart-workshop'
          SINCE 1 hour ago
        NRQL
      }
    }

    # Pod Status
    widget_table {
      title  = "Status dos Pods"
      row    = 4
      column = 5
      width  = 8
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT latest(status) as 'Status', 
                 latest(isReady) as 'Ready',
                 latest(restartCount) as 'Restarts'
          FROM K8sPodSample
          WHERE clusterName = 'smart-workshop-eks-cluster'
          AND namespaceName = 'smart-workshop'
          FACET podName
          SINCE 5 minutes ago
        NRQL
      }
    }

    # Network I/O
    widget_line {
      title  = "Network I/O (KB/s)"
      row    = 7
      column = 1
      width  = 12
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT 
            rate(sum(net.rxBytesPerSecond), 1 second) / 1024 as 'RX KB/s',
            rate(sum(net.txBytesPerSecond), 1 second) / 1024 as 'TX KB/s'
          FROM K8sPodSample
          WHERE clusterName = 'smart-workshop-eks-cluster'
          AND namespaceName = 'smart-workshop'
          TIMESERIES AUTO
          SINCE 1 hour ago
        NRQL
      }
    }
  }

  page {
    name = "Errors & Health"

    # Top Errors
    widget_table {
      title  = "Top Errors (últimas 24h)"
      row    = 1
      column = 1
      width  = 12
      height = 4

      nrql_query {
        query = <<-NRQL
          SELECT count(*) as 'Count',
                 latest(error.message) as 'Message',
                 latest(error.class) as 'Exception Type'
          FROM TransactionError
          WHERE appName = '${var.app_name}'
          FACET error.class
          SINCE 24 hours ago
          LIMIT 10
        NRQL
      }
    }

    # Error Rate por Endpoint
    widget_bar {
      title  = "Error Rate por Endpoint (%)"
      row    = 5
      column = 1
      width  = 6
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT percentage(count(*), WHERE error IS true) as 'Error %'
          FROM Transaction
          WHERE appName = '${var.app_name}'
          FACET request.uri
          SINCE 24 hours ago
          LIMIT 10
        NRQL
      }
    }

    # Health Check Status
    widget_line {
      title  = "Health Check Response Time (ms)"
      row    = 5
      column = 7
      width  = 6
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT average(duration * 1000) as 'Response Time'
          FROM Transaction
          WHERE appName = '${var.app_name}'
          AND request.uri = '/health'
          TIMESERIES AUTO
          SINCE 1 hour ago
        NRQL
      }
    }

    # Apdex Score
    widget_billboard {
      title  = "Apdex Score (User Satisfaction)"
      row    = 8
      column = 1
      width  = 4
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT apdex(duration, t: 0.5) as 'Apdex'
          FROM Transaction
          WHERE appName = '${var.app_name}'
          SINCE 1 hour ago
        NRQL
      }
    }

    # Error Count Trend
    widget_line {
      title  = "Error Count Trend"
      row    = 8
      column = 5
      width  = 8
      height = 3

      nrql_query {
        query = <<-NRQL
          SELECT count(*) as 'Errors'
          FROM TransactionError
          WHERE appName = '${var.app_name}'
          TIMESERIES AUTO
          SINCE 24 hours ago
        NRQL
      }
    }
  }
}
