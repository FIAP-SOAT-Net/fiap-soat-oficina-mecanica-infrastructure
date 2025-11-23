# 💰 Otimização para AWS Free Tier

Este documento detalha as otimizações implementadas para reduzir custos e aproveitar o AWS Free Tier.

## 📊 Comparação de Custos

### Configuração Original
| Recurso | Especificação | Custo Mensal |
|---------|---------------|--------------|
| EKS Control Plane | 1 cluster | $73.00 |
| EC2 Nodes | 2x t3.medium (24/7) | $60.00 |
| Load Balancers | 2x Classic LB | $36.00 |
| EBS Volumes | 40GB gp3 | $4.00 |
| Data Transfer | ~10GB | $1.00 |
| **Total** | | **$174.00/mês** |

### Configuração Otimizada (Free Tier)
| Recurso | Especificação | Custo Mensal |
|---------|---------------|--------------|
| EKS Control Plane | 1 cluster | $73.00 |
| EC2 Nodes | 1x t3.small (750h)* | $0.00 ✅ |
| Load Balancer | 1x Classic LB | $18.00 |
| EBS Volumes | 20GB gp3 | $2.00 |
| Data Transfer | ~5GB | $0.00 ✅ |
| **Total** | | **~$93.00/mês** |

**Economia: $81.00/mês (46% de redução!)**

\* **Free Tier**: 750 horas/mês de t3.small = 1 instância 24/7 grátis no primeiro ano

## 🎯 Otimizações Implementadas

### 1. **Instance Type: t3.small**
**Antes**: 2x t3.medium ($0.0416/hora cada = $60/mês)  
**Depois**: 1x t3.small ($0.0208/hora = **FREE** no primeiro ano)

- ✅ **Free Tier**: 750 horas/mês de t2/t3.small grátis
- ✅ 2 vCPUs, 2GB RAM (suficiente para ambiente acadêmico)
- ✅ 1 node rodando 24/7 = 720 horas/mês ≤ 750 horas FREE

### 2. **Nodes: 1 node (pode escalar para 2)**
**Antes**: 2-5 nodes  
**Depois**: 1-2 nodes

- ✅ 1 node suficiente para desenvolvimento
- ✅ Pode escalar para 2 nodes em caso de alta carga
- ✅ Reduz custos de compute em 50%

### 3. **API Replicas: 1-2 (mantém scaling!)**
**Antes**: 2-5 replicas  
**Depois**: 1-2 replicas

- ✅ HPA configurado: min 1, max 2
- ✅ Escala automaticamente quando CPU > 70%
- ✅ **Mantém capacidade de scaling!**
- ✅ Suficiente para tráfego acadêmico

### 4. **MailHog: ClusterIP (sem LoadBalancer)**
**Antes**: LoadBalancer (~$18/mês)  
**Depois**: ClusterIP (grátis)

- ✅ Economia de $18/mês
- ✅ Acesso via `kubectl port-forward`
- ❓ Sem IP externo (apenas para desenvolvimento)

**Como acessar MailHog:**
```bash
kubectl port-forward -n smart-workshop svc/mailhog-service 8025:8025
# Acessar: http://localhost:8025
```

### 5. **Resources Reduzidos**
**API Pod Antes**:
- CPU: 250m request, 500m limit
- Memory: 512Mi request, 1Gi limit

**API Pod Depois**:
- CPU: 100m request, 250m limit
- Memory: 256Mi request, 512Mi limit

- ✅ Adequado para t3.small (2 vCPUs)
- ✅ Permite rodar API + MailHog no mesmo node

## 📋 AWS Free Tier Detalhes

### O que está coberto pelo Free Tier (primeiro ano):

✅ **EC2**:
- 750 horas/mês de t2.micro ou t3.small
- 1 instância t3.small 24/7 = **GRÁTIS**

✅ **EBS**:
- 30GB de storage gp2 ou gp3
- Nosso uso: 20GB = **GRÁTIS**

✅ **Data Transfer**:
- 15GB de saída por mês
- Nosso uso: ~5GB = **GRÁTIS**

❌ **EKS Control Plane**:
- **NÃO** tem Free Tier
- Custo fixo: $73/mês

❌ **Load Balancer**:
- **NÃO** tem Free Tier
- Custo: ~$18/mês (1 LB)

## 💡 Alternativas Ainda Mais Baratas

Se os $93/mês ainda são altos para projeto acadêmico, considere:

### Opção A: ECS Fargate (~$30-40/mês)
- Remove necessidade de EKS (-$73)
- Cobra apenas por uso
- Mantém containerização

### Opção B: EC2 + Docker Compose (~$15-20/mês)
- 1x t3.small (Free Tier)
- Docker Compose direto no EC2
- Sem Kubernetes overhead
- **Mais simples e mais barato**

### Opção C: AWS App Runner (~$25/mês)
- Serverless container service
- Auto scaling
- Menos configuração

### Comparação de Custos:

| Solução | Custo/mês | Complexidade | Free Tier |
|---------|-----------|--------------|-----------|
| **EKS (atual otimizado)** | **$93** | Alta | Parcial |
| ECS Fargate | $30-40 | Média | Sim |
| EC2 + Docker | $15-20 | Baixa | Sim |
| App Runner | $25 | Baixa | Parcial |

## 🚀 Como Aplicar as Otimizações

As otimizações já estão aplicadas nos arquivos do projeto. Para deploy:

### Via GitHub Actions:
```bash
# 1. Configurar secrets (mesmos de antes)
# 2. Actions → Deploy Infrastructure → Run workflow
```

### Via Terraform:
```bash
cd terraform

# Usar terraform.tfvars.example como base
cp terraform.tfvars.example terraform.tfvars

# Editar se necessário (já está otimizado)
nano terraform.tfvars

# Deploy
terraform init
terraform plan
terraform apply
```

## 📊 Monitoramento de Custos

### Configurar AWS Budget Alert:

```bash
# Criar alerta quando custo ultrapassar $100
aws budgets create-budget \
  --account-id YOUR_ACCOUNT_ID \
  --budget file://budget.json
```

**budget.json**:
```json
{
  "BudgetName": "SmartWorkshop-Monthly",
  "BudgetLimit": {
    "Amount": "100",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

### Verificar Custos Atuais:

```bash
# Via AWS Console
# Cost Explorer → Group by Service

# Via CLI
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=SERVICE
```

## ⚠️ Limitações do Free Tier

### Válido apenas no primeiro ano:
- Após 12 meses, t3.small volta a cobrar
- Custo seria: ~$15/mês (1 node 24/7)
- Total após Free Tier expirar: ~$108/mês

### Limites:
- ⚠️ 750 horas/mês = exatamente 1 instância 24/7
- ⚠️ Se escalar para 2 nodes, paga o segundo
- ⚠️ Se usar > 30GB EBS, paga o excedente

## 💰 Estimativa de Economia Anual

### Com otimizações:
- Meses 1-12 (Free Tier ativo): $93/mês
- **Total ano 1**: $1,116

### Sem otimizações:
- Meses 1-12: $174/mês
- **Total ano 1**: $2,088

**Economia total**: $972 no primeiro ano! 🎉

## 🎓 Recomendações para Projeto Acadêmico

### Para economizar ainda mais:

1. **Usar scheduler agressivo**:
   - Parar nos fins de semana
   - Economiza ~$250/ano adicional

2. **Destroy quando não estiver apresentando**:
   - Manter apenas RDS
   - Recriar quando necessário
   - Economiza ~$600/ano

3. **Considerar créditos AWS Educate**:
   - $100-200 em créditos para estudantes
   - Pode cobrir 2-3 meses de uso

4. **Usar reservations se for longo prazo**:
   - Reserved Instances: até 62% desconto
   - Savings Plans: até 72% desconto

## 📞 Suporte

Para dúvidas sobre custos ou otimizações, consulte:
- AWS Free Tier: https://aws.amazon.com/free/
- AWS Pricing Calculator: https://calculator.aws/
- AWS Cost Explorer: Console AWS

---

**Última atualização**: 23/11/2025  
**Status**: ✅ Otimizado para Free Tier  
**Economia**: $81/mês (46% de redução)
