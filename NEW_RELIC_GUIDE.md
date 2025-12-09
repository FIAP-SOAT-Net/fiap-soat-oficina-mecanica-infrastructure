# 🔭 New Relic Observability - Guia Completo

Sistema completo de observabilidade para Smart Mechanical Workshop usando New Relic APM, Infrastructure Monitoring e Custom Business Metrics.

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Funcionalidades Implementadas](#funcionalidades-implementadas)
3. [Configuração Inicial](#configuração-inicial)
4. [Deploy](#deploy)
5. [Dashboards](#dashboards)
6. [Alertas](#alertas)
7. [Queries NRQL Úteis](#queries-nrql-úteis)
8. [Troubleshooting](#troubleshooting)
9. [Otimização de Custos](#otimização-de-custos)

---

## 🎯 Visão Geral

### Arquitetura de Observabilidade

```
┌─────────────────────────────────────────────────────────────┐
│                    New Relic Platform                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   APM Agent  │  │ K8s Metrics  │  │  Dashboards  │     │
│  │   (dotnet)   │  │ (DaemonSet)  │  │   & Alerts   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                 │                   │             │
└─────────┼─────────────────┼───────────────────┼─────────────┘
          │                 │                   │
          ▼                 ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                      EKS Cluster (AWS)                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │  Namespace: smart-workshop                      │         │
│  │  ┌──────────────────────────────────────────┐  │         │
│  │  │   API Pod (with New Relic Agent)         │  │         │
│  │  │   - Custom Events                        │  │         │
│  │  │   - Transaction Tracing                  │  │         │
│  │  │   - Error Tracking                       │  │         │
│  │  │   - Logs (JSON structured)               │  │         │
│  │  └──────────────────────────────────────────┘  │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │  Namespace: newrelic                            │         │
│  │  ┌──────────────────────────────────────────┐  │         │
│  │  │   Infrastructure Agent (DaemonSet)       │  │         │
│  │  │   - CPU/Memory monitoring                │  │         │
│  │  │   - Pod metrics                          │  │         │
│  │  │   - Network I/O                          │  │         │
│  │  └──────────────────────────────────────────┘  │         │
│  │  ┌──────────────────────────────────────────┐  │         │
│  │  │   Kube-State-Metrics                     │  │         │
│  │  │   - Cluster-level metrics                │  │         │
│  │  └──────────────────────────────────────────┘  │         │
│  └────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Funcionalidades Implementadas

### 1. APM - Application Performance Monitoring

#### Monitoramento Automático
- ✅ **Latência das APIs** (p50, p95, p99)
- ✅ **Throughput** (requisições por minuto)
- ✅ **Taxa de erro** por endpoint
- ✅ **Distributed Tracing** entre serviços
- ✅ **Database queries** com obfuscação de SQL
- ✅ **Transaction naming** automático

#### Custom Business Metrics
- ✅ **Service Order Events**:
  - Criação de ordens (action: created)
  - Mudança de status (action: updated)
  - Atributos: orderId, customerId, status, duration, vehicleId, servicesCount
  
- ✅ **Custom Metrics**:
  - `Custom/ServiceOrder/Duration/{Status}` - Duração por status
  - `Custom/ServiceOrder/Count/{Status}` - Contagem por status
  - `Custom/ServiceOrder/ServicesPerOrder` - Serviços por ordem

#### Error Tracking
- ✅ Captura automática de exceptions
- ✅ Stack traces completos
- ✅ Context attributes (customerId, orderId, operation)
- ✅ Agrupamento inteligente de erros

### 2. Infrastructure Monitoring (Kubernetes)

#### Métricas de Cluster
- ✅ **CPU/Memory** por pod e namespace
- ✅ **Pod restarts** e crash loops
- ✅ **Network I/O** (TX/RX)
- ✅ **Pod status** (Running, Pending, Failed)
- ✅ **Node capacity** e utilização

#### Kube-State-Metrics
- ✅ Deployments status
- ✅ ReplicaSets health
- ✅ Service endpoints
- ✅ PersistentVolumes status

### 3. Logs Estruturados

- ✅ **Formato JSON** (Compact JSON)
- ✅ **Correlation IDs** automáticos
- ✅ **Request enrichment** (path, method, user-agent)
- ✅ **Business context** (orderId, customerId)
- ✅ **Captura automática** pelo New Relic Agent

### 4. Dashboards

Dashboards provisionados via Terraform:

#### Overview Dashboard
- Volume diário de ordens de serviço
- Distribuição por status
- Taxa de erro geral
- Latência (p50, p95, p99)
- Throughput

#### Service Orders - Business Metrics
- **Tempo médio por fase**:
  - Diagnóstico: Received → UnderDiagnosis → WaitingApproval
  - Execução: InProgress → Completed
  - Finalização: Delivered
- Timeline de ordens (últimos 7 dias)
- Distribuição de serviços por ordem
- Taxa de conversão (aprovação vs rejeição)

#### Infrastructure - Kubernetes
- CPU usage por pod
- Memory usage por pod
- Pod restarts
- Network I/O
- Pod status table

#### Errors & Health
- Top errors (últimas 24h)
- Error rate por endpoint
- Health check response time
- Apdex score
- Error count trend

### 5. Alertas

9 alertas configurados via Terraform:

| Alerta | Threshold | Janela |
|--------|-----------|--------|
| Alta Latência | p95 > 2s | 5 min |
| Alta Taxa de Erro | > 5% | 5 min |
| Falhas em Service Orders | > 10 erros | 5 min |
| Health Check Failing | > 50% falhas | 3 min |
| Alto CPU | > 80% | 5 min |
| Alta Memória | > 85% | 5 min |
| Pod Restart Loops | > 5 restarts | 5 min |
| Baixo Throughput | < 1 req/min | 10 min |
| Database Errors | > 5 erros | 5 min |

---

## 🚀 Configuração Inicial

### Pré-requisitos

1. **Conta New Relic** (gratuita)
   - Acesse: https://newrelic.com/signup
   - Tier gratuito: 100GB/mês de dados, 1 usuário

2. **Obter Credenciais**

   a) **License Key**:
   - Acesse: https://one.newrelic.com/admin-portal/api-keys/home
   - Clique em "Create a key"
   - Tipo: License key
   - Copie e guarde

   b) **User API Key** (para Terraform):
   - Mesmo local: https://one.newrelic.com/admin-portal/api-keys/home
   - Clique em "Create a key"
   - Tipo: User
   - Copie e guarde

   c) **Account ID**:
   - Encontre no canto superior direito do console New Relic
   - Ou em: https://one.newrelic.com > Account Settings

### Configurar GitHub Secrets

Adicione os seguintes secrets no repositório GitHub:

#### Para API (fiap-soat-oficina-mecanica-infrastructure)

```bash
# AWS
AWS_ROLE_ARN=arn:aws:iam::ACCOUNT_ID:role/github-actions-role
AWS_REGION=us-west-2
VPC_ID=vpc-xxxxx
RDS_ENDPOINT=your-rds-endpoint.rds.amazonaws.com

# Database
DB_PASSWORD=your-db-password

# JWT
JWT_SECRET_KEY=your-jwt-secret-key-at-least-32-characters

# New Relic
NEW_RELIC_LICENSE_KEY=eu01xxNRAL...
NEW_RELIC_ACCOUNT_ID=1234567
NEW_RELIC_API_KEY=NRAK-...
ALERT_EMAIL=team@example.com
```

---

## 📦 Deploy

### Ordem de Deploy

#### 1. Deploy da API com New Relic Agent

```bash
# Via GitHub Actions
# Acesse: Actions > Deploy API with New Relic > Run workflow
```

Ou manualmente:

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name smart-workshop-eks-cluster

# Create namespace
kubectl create namespace smart-workshop

# Create secrets
kubectl create secret generic api-secret \
  --from-literal=DB_CONNECTION_STRING="server=YOUR_RDS;..." \
  --from-literal=JWT_SECRET_KEY="your-jwt-key" \
  --from-literal=NEW_RELIC_LICENSE_KEY="your-license-key" \
  --namespace=smart-workshop

# Deploy
kubectl apply -f k8s/api/configmap.yaml
kubectl apply -f k8s/api/deployment.yaml
kubectl apply -f k8s/api/service.yaml
```

#### 2. Deploy New Relic Kubernetes Integration

```bash
# Via GitHub Actions
# Acesse: Actions > Deploy New Relic K8s Integration > Run workflow > deploy
```

Ou manualmente:

```bash
# Create namespace
kubectl create namespace newrelic

# Create secret
kubectl create secret generic newrelic-bundle-newrelic-infrastructure-config \
  --from-literal=license="your-license-key" \
  --from-literal=cluster="smart-workshop-eks-cluster" \
  --namespace=newrelic

# Deploy
kubectl apply -f k8s/observability/newrelic-kubernetes-integration.yaml

# Verify
kubectl get pods -n newrelic
kubectl logs -n newrelic -l app=newrelic-infrastructure --tail=50
```

#### 3. Deploy Dashboards e Alertas (Terraform)

```bash
# Via GitHub Actions
# Acesse: Actions > Deploy New Relic Observability > Run workflow > apply
```

Ou manualmente:

```bash
cd terraform/modules/newrelic-observability

# Create terraform.tfvars
cat > terraform.tfvars << EOF
newrelic_account_id = "1234567"
newrelic_api_key    = "NRAK-..."
newrelic_region     = "US"
app_name            = "smart-mechanical-workshop-api"
alert_email         = "team@example.com"
environment         = "production"
EOF

# Deploy
terraform init
terraform plan
terraform apply

# Get dashboard URL
terraform output dashboard_url
```

---

## 📊 Dashboards

### Acessar Dashboards

1. Acesse: https://one.newrelic.com/dashboards
2. Procure por: "Smart Mechanical Workshop - Overview"

Ou use a URL do output do Terraform:

```bash
cd terraform/modules/newrelic-observability
terraform output dashboard_url
```

### Estrutura dos Dashboards

```
Smart Mechanical Workshop - Overview
├── Page 1: Overview
│   ├── Volume Diário de Ordens
│   ├── Ordens por Status
│   ├── Taxa de Erro (24h)
│   ├── Latência (p50, p95, p99)
│   └── Throughput
├── Page 2: Service Orders - Business Metrics
│   ├── Tempo Médio - Diagnóstico
│   ├── Tempo Médio - Execução
│   ├── Tempo Médio - Finalização
│   ├── Timeline de Ordens (7 dias)
│   ├── Distribuição de Serviços
│   └── Taxa de Conversão
├── Page 3: Infrastructure - Kubernetes
│   ├── CPU Usage por Pod
│   ├── Memory Usage por Pod
│   ├── Pod Restarts
│   ├── Pod Status Table
│   └── Network I/O
└── Page 4: Errors & Health
    ├── Top Errors
    ├── Error Rate por Endpoint
    ├── Health Check Response Time
    ├── Apdex Score
    └── Error Count Trend
```

---

## 🚨 Alertas

### Configuração de Notificações

Os alertas são enviados para o email configurado em `ALERT_EMAIL`.

### Policy: Smart Mechanical Workshop - Alerts

| Alerta | Descrição | Criticidade |
|--------|-----------|-------------|
| Alta Latência | p95 > 2s por 5 minutos | Warning: 1.5s, Critical: 2s |
| Alta Taxa de Erro | > 5% de erros por 5 minutos | Warning: 2%, Critical: 5% |
| Falhas em Service Orders | > 10 erros em 5 minutos | Warning: 5, Critical: 10 |
| Health Check Failing | > 50% falhas em 3 minutos | Critical: 50% |
| Alto CPU | > 80% por 5 minutos | Warning: 70%, Critical: 80% |
| Alta Memória | > 85% por 5 minutos | Warning: 75%, Critical: 85% |
| Pod Restart Loops | > 5 restarts em 5 minutos | Critical: 5 |
| Baixo Throughput | < 1 req/min por 10 minutos | Critical: 1 |
| Database Errors | > 5 erros em 5 minutos | Critical: 5 |

### Silenciar Alertas

```bash
# Via New Relic UI
# Acesse: Alerts & AI > Alert Policies > Smart Mechanical Workshop - Alerts
# Clique em "Mute" na policy ou condition específica
```

---

## 🔍 Queries NRQL Úteis

### Queries de Negócio

#### Volume de Ordens por Dia

```sql
SELECT count(*) as 'Total de Ordens'
FROM ServiceOrder
WHERE action = 'created'
FACET dateOf(timestamp)
SINCE 7 days ago
TIMESERIES 1 day
```

#### Tempo Médio por Status (Diagnóstico)

```sql
SELECT average(durationMs) / 60000 as 'Minutos'
FROM ServiceOrder
WHERE status IN ('Received', 'UnderDiagnosis', 'WaitingApproval')
FACET status
SINCE 7 days ago
```

#### Taxa de Conversão (Aprovação vs Rejeição)

```sql
SELECT 
  filter(count(*), WHERE status = 'Delivered') as 'Aprovadas',
  filter(count(*), WHERE status IN ('Rejected', 'Cancelled')) as 'Rejeitadas',
  percentage(count(*), WHERE status = 'Delivered') as 'Taxa de Aprovação %'
FROM ServiceOrder
SINCE 7 days ago
```

#### Top Clientes por Volume de Ordens

```sql
SELECT count(*) as 'Total de Ordens'
FROM ServiceOrder
WHERE action = 'created'
FACET customerId
SINCE 30 days ago
LIMIT 10
```

### Queries de Performance

#### Endpoints Mais Lentos

```sql
SELECT 
  percentile(duration, 95) as 'p95',
  count(*) as 'Requests'
FROM Transaction
WHERE appName = 'smart-mechanical-workshop-api'
FACET request.uri
SINCE 24 hours ago
LIMIT 10
```

#### Error Rate por Endpoint

```sql
SELECT 
  count(*) as 'Total',
  filter(count(*), WHERE error IS true) as 'Errors',
  percentage(count(*), WHERE error IS true) as 'Error Rate %'
FROM Transaction
WHERE appName = 'smart-mechanical-workshop-api'
FACET request.uri
SINCE 24 hours ago
```

#### Database Query Performance

```sql
SELECT 
  average(databaseDuration) as 'Avg DB Time (s)',
  percentile(databaseDuration, 95) as 'p95 DB Time'
FROM Transaction
WHERE appName = 'smart-mechanical-workshop-api'
AND databaseDuration IS NOT NULL
TIMESERIES AUTO
SINCE 1 hour ago
```

### Queries de Infraestrutura

#### CPU e Memória por Pod

```sql
SELECT 
  average(cpuUsedCores / cpuLimitCores * 100) as 'CPU %',
  average(memoryUsedBytes / memoryLimitBytes * 100) as 'Memory %'
FROM K8sPodSample
WHERE clusterName = 'smart-workshop-eks-cluster'
AND namespaceName = 'smart-workshop'
FACET podName
TIMESERIES AUTO
SINCE 1 hour ago
```

#### Pods com Mais Restarts

```sql
SELECT latest(restartCount) as 'Restarts'
FROM K8sContainerSample
WHERE clusterName = 'smart-workshop-eks-cluster'
AND namespaceName = 'smart-workshop'
FACET podName
SINCE 24 hours ago
```

---

## 🔧 Troubleshooting

### New Relic Agent Não Conecta

1. **Verificar License Key**:
```bash
kubectl get secret api-secret -n smart-workshop -o jsonpath='{.data.NEW_RELIC_LICENSE_KEY}' | base64 -d
```

2. **Verificar Logs do Pod**:
```bash
POD_NAME=$(kubectl get pods -n smart-workshop -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME -n smart-workshop | grep -i "new relic"
```

3. **Variáveis de Ambiente**:
```bash
kubectl exec $POD_NAME -n smart-workshop -- env | grep NEW_RELIC
```

### DaemonSet Não Inicia

1. **Verificar Pods**:
```bash
kubectl get pods -n newrelic
kubectl describe pod -n newrelic -l app=newrelic-infrastructure
```

2. **Verificar Secret**:
```bash
kubectl get secret newrelic-bundle-newrelic-infrastructure-config -n newrelic
```

3. **Verificar Logs**:
```bash
kubectl logs -n newrelic -l app=newrelic-infrastructure --tail=100
```

### Dashboards Não Mostram Dados

1. **Verificar se agent está enviando dados**:
   - Acesse: https://one.newrelic.com/apm
   - Procure por: "smart-mechanical-workshop-api"
   - Deve aparecer na lista

2. **Verificar custom events**:
```sql
SELECT count(*) 
FROM ServiceOrder 
SINCE 1 hour ago
```

3. **Verificar métricas K8s**:
```sql
SELECT count(*) 
FROM K8sPodSample 
WHERE clusterName = 'smart-workshop-eks-cluster'
SINCE 5 minutes ago
```

### Alertas Não Disparam

1. **Verificar Policy**:
   - Acesse: https://one.newrelic.com/alerts-ai/policies
   - Procure por: "Smart Mechanical Workshop - Alerts"

2. **Verificar Workflow**:
   - Acesse: Alerts & AI > Workflows
   - Procure por: "Workshop Alert Workflow"
   - Verificar se está conectado ao canal de email

3. **Testar Alerta Manualmente**:
```bash
# Gerar carga para disparar alerta de latência
for i in {1..100}; do
  curl http://API_URL:5180/api/serviceorders
done
```

---

## 💰 Otimização de Custos

### Configurações de Free Tier

O projeto está configurado para operar dentro do free tier do New Relic:

- **100 GB/mês de dados** inclusos
- **1 usuário** incluído
- **Retenção**: 8 dias para eventos

### Otimizações Implementadas

#### 1. Sampling de Dados

**Dockerfile**:
```dockerfile
ENV NEW_RELIC_SPAN_EVENTS_MAX_SAMPLES_STORED=2000
ENV NEW_RELIC_CUSTOM_EVENTS_MAX_SAMPLES_STORED=10000
ENV NEW_RELIC_TRANSACTION_EVENTS_MAX_SAMPLES_STORED=2000
```

#### 2. SQL Obfuscation

```dockerfile
ENV NEW_RELIC_TRANSACTION_TRACER_RECORD_SQL=obfuscated
```

#### 3. Filtros de Logs

**K8s Integration** (newrelic-kubernetes-integration.yaml):
```yaml
metrics_process_sample_rate: 20
metrics_storage_sample_rate: 20
metrics_network_sample_rate: 10
```

#### 4. Filtros de Métricas High Cardinality

```yaml
transformations:
  - description: "Filter high cardinality metrics"
    ignore_metrics:
      - prefixes:
          - "go_"
          - "process_"
```

### Monitorar Consumo

1. **Acesse**: https://one.newrelic.com/admin-portal/centralized-admin-user/data-usage
2. **Visualize**:
   - Total de GB consumidos no mês
   - Breakdown por tipo de dado (APM, Infra, Logs, etc)
   - Projeção mensal

### Ajustar se Necessário

Se estiver próximo do limite:

#### Reduzir Sampling no Dockerfile

```dockerfile
ENV NEW_RELIC_SPAN_EVENTS_MAX_SAMPLES_STORED=1000
ENV NEW_RELIC_CUSTOM_EVENTS_MAX_SAMPLES_STORED=5000
ENV NEW_RELIC_TRANSACTION_EVENTS_MAX_SAMPLES_STORED=1000
```

#### Desabilitar Logs no K8s Integration

```yaml
# Remover seção log_forward do newrelic-infra.yml
```

#### Ajustar Sampling Rate no K8s

```yaml
metrics_process_sample_rate: 30  # Era 20
metrics_storage_sample_rate: 30   # Era 20
```

---

## 📚 Recursos Adicionais

### Documentação

- [New Relic APM for .NET](https://docs.newrelic.com/docs/apm/agents/net-agent/)
- [New Relic Kubernetes Integration](https://docs.newrelic.com/docs/kubernetes-pixie/kubernetes-integration/get-started/introduction-kubernetes-integration/)
- [NRQL Reference](https://docs.newrelic.com/docs/nrql/nrql-syntax-clauses-functions/)
- [Terraform Provider](https://registry.terraform.io/providers/newrelic/newrelic/latest/docs)

### Exemplos de Dashboards

- [New Relic Quickstarts](https://newrelic.com/instant-observability/)
- [Dashboard Examples](https://docs.newrelic.com/docs/query-your-data/explore-query-data/dashboards/introduction-dashboards/)

### Suporte

- [New Relic Community](https://discuss.newrelic.com/)
- [GitHub Issues](https://github.com/newrelic/newrelic-dotnet-agent/issues)

---

## ✅ Checklist de Implementação

- [x] New Relic Agent configurado no Dockerfile
- [x] Custom events para Service Orders
- [x] Métricas de negócio implementadas
- [x] Logs estruturados em JSON
- [x] Kubernetes manifests atualizados
- [x] New Relic K8s Integration configurada
- [x] Dashboards provisionados via Terraform
- [x] 9 Alertas configurados
- [x] GitHub Actions workflows criados
- [x] Documentação completa
- [x] Otimização de custos implementada

---

## 🎉 Conclusão

A implementação do New Relic fornece observabilidade completa da aplicação Smart Mechanical Workshop, incluindo:

✅ **Monitoramento de Performance**: Latência, throughput, error rate  
✅ **Métricas de Negócio**: Volume de ordens, tempo por fase, conversão  
✅ **Infraestrutura**: CPU, memória, pods, network  
✅ **Alertas Proativos**: 9 alertas configurados para falhas críticas  
✅ **Dashboards Visuais**: 4 páginas com 30+ widgets  
✅ **Automação**: Deploy via GitHub Actions  
✅ **Custos Otimizados**: Configurado para free tier

**Próximos Passos**:
1. Execute os workflows do GitHub Actions
2. Acesse os dashboards no New Relic
3. Teste os alertas criando cenários de erro
4. Monitore o consumo de dados
5. Ajuste thresholds dos alertas conforme necessário
