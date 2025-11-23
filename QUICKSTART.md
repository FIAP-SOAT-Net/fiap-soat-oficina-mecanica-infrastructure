# 🚀 Quick Start Guide

Guia rápido para começar a usar a infraestrutura do Smart Workshop.

## 📋 Índice

- [Ambiente Local](#ambiente-local)
- [Deploy AWS](#deploy-aws)
- [Comandos Úteis](#comandos-úteis)

## 🐳 Ambiente Local

### 1. Pré-requisitos
```bash
# Verificar Docker
docker --version
docker-compose --version
```

### 2. Configurar Variáveis
```bash
cd docker
cp .env.local.example .env.local
nano .env.local  # Editar configurações do banco
```

### 3. Iniciar
```bash
docker-compose up -d
```

### 4. Acessar
- **API**: http://localhost:5180
- **Swagger**: http://localhost:5180/swagger
- **Health**: http://localhost:5180/health
- **MailHog**: http://localhost:8025

### 5. Parar
```bash
docker-compose down
```

## ☁️ Deploy AWS

### Opção 1: Via GitHub Actions (Recomendado)

#### Passo 1: Configurar Secrets

No GitHub, vá em **Settings → Secrets and variables → Actions** e adicione:

| Secret | Valor | Exemplo |
|--------|-------|---------|
| `AWS_ROLE_ARN` | ARN da role IAM | `arn:aws:iam::243100982781:role/GitHubActionsRole` |
| `AWS_REGION` | Região AWS | `us-west-2` |
| `VPC_ID` | ID da VPC | `vpc-xxxxxxxxxxxxx` |
| `SUBNET_IDS` | JSON com subnet IDs | `["subnet-xxx","subnet-yyy"]` |
| `RDS_ENDPOINT` | Endpoint do RDS | `smart-workshop-dev-db.xxx.rds.amazonaws.com` |
| `DB_PASSWORD` | Senha do banco | `SuaSenhaSegura123!` |
| `JWT_SECRET_KEY` | Chave JWT (32+ chars) | `your-secret-key-32-chars-min` |

#### Passo 2: Obter Informações da VPC e Subnets

```bash
# VPC ID (do RDS)
aws ec2 describe-vpcs --query "Vpcs[?IsDefault==false].VpcId" --output text

# Subnet IDs (precisa de 2+ em AZs diferentes)
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-xxxxxxxxxxxxx" \
  --query "Subnets[].[SubnetId,AvailabilityZone]" \
  --output table

# Formato do JSON para SUBNET_IDS:
["subnet-xxxxxxxxxxxxx","subnet-yyyyyyyyyyyyy"]
```

#### Passo 3: Executar Deploy

1. Vá em **Actions** no GitHub
2. Selecione **🚀 Deploy Infrastructure**
3. Clique em **Run workflow**
4. Aguarde 15-20 minutos

#### Passo 4: Acessar Serviços

Após o deploy, obtenha os endpoints:

```bash
# Configurar kubectl
aws eks update-kubeconfig --region us-west-2 --name smart-workshop-dev-cluster

# Ver serviços
kubectl get svc -n smart-workshop

# API Endpoint (LoadBalancer)
kubectl get svc api-service -n smart-workshop \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# MailHog (ClusterIP - usar port-forward)
kubectl port-forward -n smart-workshop svc/mailhog-service 8025:8025
# Acessar: http://localhost:8025
```

**💡 Nota Free Tier**: MailHog usa ClusterIP (sem LoadBalancer) para economizar ~$18/mês.

### Opção 2: Deploy Local via Terraform

#### Passo 1: Configurar Variáveis

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Editar com suas configurações
```

#### Passo 2: Aplicar Terraform

```bash
# Inicializar
terraform init

# Validar
terraform validate

# Preview
terraform plan

# Aplicar
terraform apply

# Configurar kubectl
aws eks update-kubeconfig --region us-west-2 --name smart-workshop-dev-cluster
```

#### Passo 3: Deploy Kubernetes

```bash
# Criar namespace
kubectl create namespace smart-workshop

# Criar secret
kubectl create secret generic api-secret \
  --from-literal=DB_CONNECTION_STRING="server=RDS_ENDPOINT;port=3306;database=smart_workshop;user=admin;password=PASSWORD;SslMode=Required;" \
  --from-literal=JWT_SECRET_KEY="your-secret-key-min-32-chars" \
  --namespace=smart-workshop

# Deploy manifestos
kubectl apply -f k8s/api/
kubectl apply -f k8s/mailhog/

# Verificar
kubectl get pods -n smart-workshop
kubectl get svc -n smart-workshop
```

## 🛠️ Comandos Úteis

### Kubernetes

```bash
# Ver todos os recursos
kubectl get all -n smart-workshop

# Ver logs da API
kubectl logs -n smart-workshop -l app=api -f

# Ver logs do MailHog
kubectl logs -n smart-workshop -l app=mailhog -f

# Escalar API
kubectl scale deployment api-deployment -n smart-workshop --replicas=3

# Ver HPA status
kubectl get hpa -n smart-workshop

# Descrever pod
kubectl describe pod POD_NAME -n smart-workshop

# Entrar em um pod
kubectl exec -it POD_NAME -n smart-workshop -- /bin/bash

# Ver eventos
kubectl get events -n smart-workshop --sort-by='.lastTimestamp'
```

### Start/Stop Infrastructure

```bash
# Iniciar infraestrutura
./scripts/start-infra.sh

# Parar infraestrutura
./scripts/stop-infra.sh

# Ou via GitHub Actions
# Actions → ⏰ Start/Stop Scheduler → Run workflow → Escolher 'start' ou 'stop'
```

### Terraform

```bash
# Ver outputs
terraform output

# Ver estado
terraform show

# Importar recurso existente
terraform import RESOURCE_TYPE.NAME RESOURCE_ID

# Destruir recurso específico
terraform destroy -target=RESOURCE_TYPE.NAME
```

### AWS CLI

```bash
# Ver cluster EKS
aws eks describe-cluster --name smart-workshop-dev-cluster --region us-west-2

# Ver node group
aws eks describe-nodegroup \
  --cluster-name smart-workshop-dev-cluster \
  --nodegroup-name smart-workshop-dev-node-group \
  --region us-west-2

# Listar load balancers
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, 'smart-workshop')]" \
  --region us-west-2
```

## 🔧 Troubleshooting Rápido

### Pods não iniciam
```bash
# Ver motivo
kubectl describe pod POD_NAME -n smart-workshop

# Ver logs
kubectl logs POD_NAME -n smart-workshop

# Forçar restart
kubectl rollout restart deployment/api-deployment -n smart-workshop
```

### LoadBalancer em pending
```bash
# Aguardar 5-10 minutos
# Verificar eventos
kubectl get events -n smart-workshop | grep LoadBalancer

# Verificar configuração AWS
aws elbv2 describe-load-balancers --region us-west-2
```

### Erro de conexão com RDS
```bash
# Verificar secret
kubectl get secret api-secret -n smart-workshop -o yaml

# Verificar Security Group do RDS
# Deve permitir conexões do Security Group do EKS
```

### Nodes não aparecem
```bash
# Ver status do node group
aws eks describe-nodegroup \
  --cluster-name smart-workshop-dev-cluster \
  --nodegroup-name smart-workshop-dev-node-group \
  --region us-west-2

# Ver logs CloudFormation
# AWS Console → CloudFormation → Stacks
```

## 📚 Próximos Passos

1. **Configurar Monitoring**: Adicionar CloudWatch Container Insights
2. **Configurar Alertas**: SNS para notificações
3. **Implementar CI/CD da API**: Build e deploy automático
4. **Adicionar Ingress**: Usar AWS Load Balancer Controller
5. **Implementar SSL/TLS**: Certificados via ACM
6. **Configurar Auto Backup**: Snapshots dos volumes
7. **Adicionar Secrets Manager**: Gerenciamento de senhas

## 🆘 Suporte

- **Documentação completa**: [README.md](README.md)
- **Issues**: https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure/issues
- **API Repo**: https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica
- **Database Repo**: https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure-database
