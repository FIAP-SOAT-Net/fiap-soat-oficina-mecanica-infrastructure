# New Relic Observability Module
# Dashboards e Alertas para Smart Mechanical Workshop

Este módulo Terraform provisiona:
- Dashboard completo com métricas de negócio e infraestrutura
- Alertas para latência, erros, health checks e recursos do Kubernetes
- Notificações por email

## Uso

```hcl
module "newrelic_observability" {
  source = "./modules/newrelic-observability"

  newrelic_account_id = "YOUR_ACCOUNT_ID"
  newrelic_api_key    = var.newrelic_api_key
  newrelic_region     = "US"
  
  app_name    = "smart-mechanical-workshop-api"
  alert_email = "team@example.com"
  environment = "production"
}
```

## Configuração

1. Obter New Relic User API Key:
   - Acesse: https://one.newrelic.com/admin-portal/api-keys/home
   - Crie uma "User API Key" com permissões de admin

2. Obter Account ID:
   - Encontre no canto superior direito do console New Relic

3. Configurar variáveis de ambiente ou GitHub Secrets:
   ```bash
   export NEW_RELIC_ACCOUNT_ID="your_account_id"
   export NEW_RELIC_API_KEY="your_api_key"
   ```

## Aplicar via Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Dashboards Criados

### Overview
- Volume diário de ordens de serviço
- Ordens por status
- Taxa de erro
- Latência (p50, p95, p99)
- Throughput

### Service Orders - Business Metrics
- Tempo médio por fase (Diagnóstico, Execução, Finalização)
- Timeline de ordens por status
- Distribuição de serviços por ordem
- Taxa de conversão (aprovação/rejeição)

### Infrastructure - Kubernetes
- CPU e memória por pod
- Pod restarts
- Network I/O
- Status dos pods

### Errors & Health
- Top errors
- Error rate por endpoint
- Health check response time
- Apdex score
- Error count trend

## Alertas Configurados

1. **Alta Latência**: p95 > 2s
2. **Alta Taxa de Erro**: > 5%
3. **Falhas em Service Orders**: > 10 erros
4. **Health Check Failing**: > 50% de falhas
5. **Alto CPU**: > 80%
6. **Alta Memória**: > 85%
7. **Pod Restart Loops**: > 5 restarts
8. **Baixo Throughput**: < 1 req/min
9. **Database Errors**: > 5 erros de conexão

## Otimização de Custos

O módulo está configurado para otimizar custos:
- Sampling configurado nos limites do free tier
- Agregação de 60 segundos
- Delay de 120 segundos para evitar falsos positivos
- Filtros para reduzir volume de dados
