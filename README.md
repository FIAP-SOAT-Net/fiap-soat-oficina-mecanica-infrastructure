# 🏗️ Oficina Mecânica Inteligente - Infraestrutura

Infraestrutura como Código (IaC) para o projeto Smart Mechanical Workshop da FIAP/SOAT, incluindo ambiente local Docker e infraestrutura AWS com EKS.

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-844FBA?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31+-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://www.docker.com/)

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Pré-requisitos](#-pré-requisitos)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Ambiente Local](#-ambiente-local)
- [Ambiente AWS (Dev)](#-ambiente-aws-dev)
- [Pipelines CI/CD](#-pipelines-cicd)
- [Custos Estimados](#-custos-estimados)
- [Troubleshooting](#-troubleshooting)

## 🎯 Visão Geral

Este repositório gerencia toda a infraestrutura necessária para executar o sistema de gestão de oficina mecânica em dois ambientes:

### 1. **Ambiente Local (Docker)**
- API .NET rodando em container
- MailHog para testes de e-mail
- Conexão com banco de dados local ou AWS RDS

### 2. **Ambiente AWS (Dev)**
- **EKS (Elastic Kubernetes Service)** - Cluster Kubernetes gerenciado
- **API .NET** - Deployed no EKS
- **MailHog** - Deployed no EKS para testes
- **RDS MySQL** - Banco de dados gerenciado (provisionado pelo [repositório database](https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure-database))
- **Auto Scaling** - HPA (Horizontal Pod Autoscaler)
- **Load Balancer** - Exposição dos serviços

## ✅ Pré-requisitos

### Ferramentas Necessárias

#### Para Desenvolvimento Local:
- [Docker](https://docs.docker.com/get-docker/) 20.10+
- [Docker Compose](https://docs.docker.com/compose/install/) 2.0+
- [Git](https://git-scm.com/downloads)

#### Para Deploy na AWS:
- [AWS CLI](https://aws.amazon.com/cli/) 2.x configurado
- [Terraform](https://www.terraform.io/downloads) 1.5+
- [kubectl](https://kubernetes.io/docs/tasks/tools/) 1.31+
- [Helm](https://helm.sh/docs/intro/install/) 3.x (opcional)
- Conta AWS com permissões adequadas

### Recursos AWS Necessários

- **Account ID**: 243100982781
- **Region**: us-west-2
- **VPC** e **Subnets** (reutilizando do RDS)
- **RDS MySQL** já provisionado ([ver repositório database](https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure-database))
- **IAM Roles** para EKS e GitHub Actions OIDC

## 📁 Estrutura do Projeto

```
fiap-soat-oficina-mecanica-infrastructure/
│
├── .github/
│   └── workflows/                      # GitHub Actions Workflows
│       ├── deploy-infrastructure.yml   # Deploy completo na AWS
│       ├── destroy-infrastructure.yml  # Destroy completo da AWS
│       └── start-stop-scheduler.yml    # Agendamento start/stop
│
├── docker/                             # Ambiente Local
│   ├── docker-compose.yml              # Compose para dev local
│   └── .env.local.example              # Exemplo de variáveis
│
├── terraform/                          # Infraestrutura AWS
│   ├── main.tf                         # Configuração principal
│   ├── variables.tf                    # Definição de variáveis
│   ├── outputs.tf                      # Outputs da infraestrutura
│   ├── backend.tf                      # S3 backend config
│   ├── versions.tf                     # Versões de providers
│   ├── eks.tf                          # Cluster EKS
│   ├── iam.tf                          # Roles e policies
│   └── terraform.tfvars.example        # Exemplo de variáveis
│
├── k8s/                                # Manifestos Kubernetes
│   ├── api/
│   │   ├── deployment.yaml             # Deployment da API
│   │   ├── service.yaml                # Service LoadBalancer
│   │   ├── configmap.yaml              # ConfigMap
│   │   ├── hpa.yaml                    # Horizontal Pod Autoscaler
│   │   └── secret.yaml.example         # Secret exemplo
│   └── mailhog/
│       ├── deployment.yaml             # Deployment MailHog
│       └── service.yaml                # Service LoadBalancer
│
├── scripts/                            # Scripts auxiliares
│   ├── start-infra.sh                  # Inicia infraestrutura AWS
│   └── stop-infra.sh                   # Para infraestrutura AWS
│
├── .env.example                        # Exemplo de variáveis globais
├── .gitignore                          # Arquivos ignorados
└── README.md                           # Esta documentação
```

## 🐳 Ambiente Local

O ambiente local permite desenvolver e testar a aplicação completa usando Docker Compose.

### Iniciar Ambiente Local

```bash
# 1. Clonar o repositório
git clone https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure.git
cd fiap-soat-oficina-mecanica-infrastructure

# 2. Configurar variáveis de ambiente
cd docker
cp .env.local.example .env.local
nano .env.local  # Ajustar conforme necessário

# 3. Subir containers
docker-compose up -d

# 4. Verificar status
docker-compose ps

# 5. Ver logs
docker-compose logs -f api
```

### Serviços Disponíveis

| Serviço | URL | Descrição |
|---------|-----|-----------|
| API | http://localhost:5180 | API Principal |
| Swagger | http://localhost:5180/swagger | Documentação interativa |
| Health Check | http://localhost:5180/health | Status da aplicação |
| MailHog UI | http://localhost:8025 | Interface web de e-mails |
| MailHog SMTP | localhost:1025 | Servidor SMTP |

### Parar Ambiente Local

```bash
# Parar containers
docker-compose down

# Parar e remover volumes (⚠️ DELETA DADOS)
docker-compose down -v
```

## ☁️ Ambiente AWS (Dev)

> 📖 **Guia Rápido**: Ver [SETUP-QUICKSTART.md](./SETUP-QUICKSTART.md) para um checklist resumido dos passos de configuração.

### Pré-requisitos AWS

Antes de começar o deploy, você precisa configurar:

1. ✅ **Backend do Terraform** (Bucket S3 + DynamoDB)
2. ✅ **IAM Role para GitHub Actions** (com permissões adequadas)
3. ✅ **Secrets no GitHub** (credenciais e configurações)

Siga os passos abaixo na ordem correta.

### Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Account (243100982781)              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    VPC (us-west-2)                         │ │
│  │                                                             │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │              EKS Cluster (1.31)                       │ │ │
│  │  │                                                        │ │ │
│  │  │  ┌─────────────────┐      ┌─────────────────┐       │ │ │
│  │  │  │  API Pods       │      │  MailHog Pod    │       │ │ │
│  │  │  │  (2-5 replicas) │      │  (1 replica)    │       │ │ │
│  │  │  │  Port: 5180     │      │  Port: 8025     │       │ │ │
│  │  │  └────────┬────────┘      └────────┬────────┘       │ │ │
│  │  │           │                         │                 │ │ │
│  │  │  ┌────────▼────────┐      ┌────────▼────────┐       │ │ │
│  │  │  │  LoadBalancer   │      │  LoadBalancer   │       │ │ │
│  │  │  │  (External IP)  │      │  (External IP)  │       │ │ │
│  │  │  └─────────────────┘      └─────────────────┘       │ │ │
│  │  │                                                        │ │ │
│  │  │  ┌─────────────────────────────────────────┐        │ │ │
│  │  │  │     Horizontal Pod Autoscaler           │        │ │ │
│  │  │  │     Min: 2, Max: 5, Target CPU: 70%     │        │ │ │
│  │  │  └─────────────────────────────────────────┘        │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │                           │                                 │ │
│  │                           │ (Connection)                    │ │
│  │                           ▼                                 │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │              RDS MySQL 8.4.3                          │ │ │
│  │  │              smart-workshop-dev-db                    │ │ │
│  │  │              Database: smart_workshop                 │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### Passo 1: Configurar Backend Terraform (Apenas uma vez)

O backend do Terraform armazena o estado da infraestrutura no S3 com lock no DynamoDB.

```bash
# Executar script de setup (cria bucket S3 e tabela DynamoDB)
./scripts/setup-terraform-backend.sh
```

**O que o script cria:**
- 🪣 **Bucket S3**: `smart-workshop-infrastructure-terraform-state`
  - Versionamento habilitado
  - Encriptação AES256
  - Acesso público bloqueado
- 🔐 **Tabela DynamoDB**: `smart-workshop-terraform-locks`
  - Lock distribuído para operações Terraform
  - Billing mode: Pay-per-request

💰 **Custo estimado**: ~$0.50/mês

---

### Passo 2: Configurar IAM Role para GitHub Actions (Apenas uma vez)

O GitHub Actions usa OIDC (OpenID Connect) para autenticar na AWS sem precisar de credenciais estáticas (mais seguro).

```bash
# Executar script de setup da role IAM
./scripts/setup-github-actions-role.sh
```

**O que o script configura:**

1. 🔐 **OIDC Provider**: Confiança entre GitHub e AWS
2. 👤 **IAM Role**: `GitHubActionsEKSRole`
3. 📋 **Políticas anexadas**:
   - `TerraformStateAccessPolicy` - Acesso ao S3 e DynamoDB
   - `EKSFullAccessPolicy` - Gerenciar cluster EKS
   - `AmazonEC2FullAccess` - Gerenciar instâncias EC2
   - `IAMFullAccess` - Criar roles e policies
   - `AmazonVPCFullAccess` - Gerenciar rede
   - `ElasticLoadBalancingFullAccess` - Gerenciar Load Balancers

**⚠️ Importante**: Anote o **Role ARN** que aparece no final da execução. Você vai precisar no próximo passo.

Exemplo de output:
```
Role ARN (adicione como secret AWS_ROLE_ARN):
arn:aws:iam::243100982781:role/GitHubActionsEKSRole
```

💰 **Custo**: $0.00 (roles IAM não têm custo)

---

### Passo 3: Configurar Secrets no GitHub

Acesse o repositório no GitHub e configure os secrets:

**Caminho**: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

| Secret Name | Descrição | Exemplo / Como obter |
|-------------|-----------|---------------------|
| `AWS_ROLE_ARN` | ARN da role IAM para OIDC | Obtido no Passo 2 (ex: `arn:aws:iam::243100982781:role/GitHubActionsEKSRole`) |
| `AWS_REGION` | Região AWS | `us-west-2` |
| `DB_PASSWORD` | Senha do banco RDS | Ver [repositório database](https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure-database) |
| `RDS_ENDPOINT` | Endpoint do RDS MySQL | Ex: `smart-workshop-dev-db.xxxxx.us-west-2.rds.amazonaws.com` |

**Como obter o RDS_ENDPOINT**:
```bash
aws rds describe-db-instances \
  --db-instance-identifier smart-workshop-dev-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

---

### Passo 4: Deploy via GitHub Actions (Recomendado)

---

### Passo 4: Deploy via GitHub Actions (Recomendado)

Com todos os secrets configurados, faça o deploy automático:

1. Acesse o repositório no GitHub
2. Vá em **Actions** → **🚀 Deploy Infrastructure**
3. Clique em **Run workflow**
4. Selecione a branch `main`
5. Aguarde ~15-20 minutos

**O workflow irá**:
- ✅ Autenticar na AWS via OIDC (sem credenciais estáticas)
- ✅ Inicializar Terraform com backend S3
- ✅ Criar cluster EKS com Fargate
- ✅ Instalar AWS Load Balancer Controller
- ✅ Fazer deploy da API e MailHog
- ✅ Configurar auto-scaling (HPA)

---

### Alternativa: Deploy Local via Terraform

Se preferir executar localmente:

```bash
cd terraform

# Inicializar (já foi feito no Passo 1)
terraform init

# Validar configuração
terraform validate

# Preview das mudanças
terraform plan

# Aplicar (criar infraestrutura)
terraform apply

# Configurar kubectl
aws eks update-kubeconfig --region us-west-2 --name smart-workshop-dev-cluster

# Verificar nodes
kubectl get nodes

# Deploy dos manifestos Kubernetes
kubectl apply -f ../k8s/api/
kubectl apply -f ../k8s/mailhog/

# Verificar pods
kubectl get pods -n smart-workshop

# Pegar endpoints externos
kubectl get svc -n smart-workshop
```

---

### Passo 5: Acessar Serviços na AWS

Após o deploy, obtenha os endpoints externos:

```bash
# API (LoadBalancer externo)
kubectl get svc api-service -n smart-workshop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# MailHog (ClusterIP - acesso via port-forward)
kubectl port-forward -n smart-workshop svc/mailhog-service 8025:8025
# Acessar: http://localhost:8025
```

**💡 Nota**: MailHog usa ClusterIP (sem LoadBalancer) para economia de custos (~$18/mês).

Ou use os outputs do Terraform:

```bash
terraform output api_endpoint
# Para MailHog, use port-forward
```

## 🤖 Pipelines CI/CD

### 1. Deploy Infrastructure (`deploy-infrastructure.yml`)

**Trigger:**
- Push na branch `main`
- Dispatch manual via interface

**O que faz:**
1. Configura credenciais AWS via OIDC
2. Executa `terraform apply`
3. Configura `kubectl`
4. Deploy dos manifestos Kubernetes
5. Valida health checks

**Execução manual:**

```
Actions → 🚀 Deploy Infrastructure → Run workflow
```

### 2. Destroy Infrastructure (`destroy-infrastructure.yml`)

**Trigger:**
- Dispatch manual via interface (proteção contra deleção acidental)

**O que faz:**
1. Remove todos os recursos Kubernetes
2. Executa `terraform destroy`
3. Limpa configurações locais

**⚠️ ATENÇÃO**: Esta ação é **DESTRUTIVA** e irá deletar toda a infraestrutura AWS!

**Execução manual:**

```
Actions → 🗑️ Destroy Infrastructure → Run workflow
```

### 3. Start/Stop Scheduler (`start-stop-scheduler.yml`)

**Trigger:**
- **Start**: Todos os dias às 07:00 (horário de Brasília - UTC-3)
- **Stop**: Todos os dias às 20:00 (horário de Brasília - UTC-3)
- Dispatch manual via interface

**O que faz:**

**Start (07:00 BRT):**
- Inicia o cluster EKS (se stopped)
- Escala deployments para número mínimo de replicas
- Valida que pods estão rodando

**Stop (20:00 BRT):**
- Escala deployments para 0 replicas
- Para node group do EKS (mantém cluster)
- Economiza ~70% dos custos durante horários ociosos

**Economia estimada**: ~$200/mês

**Execução manual:**

```
Actions → ⏰ Start/Stop Scheduler → Run workflow → Escolher 'start' ou 'stop'
```

## 💰 Custos Estimados

### Ambiente Dev (AWS) - **OTIMIZADO PARA FREE TIER**

| Recurso | Especificação | Custo Mensal (Free Tier) | Custo Após Free Tier |
|---------|---------------|--------------------------|----------------------|
| EKS Cluster | Control Plane | $73.00 | $73.00 |
| EC2 Nodes | 1x t3.small (750h)* | **$0.00** ✅ | ~$15.00 |
| Load Balancer | 1x Classic LB | $18.00 | $18.00 |
| EBS Volumes | 20GB gp3 | **$0.00** ✅ | ~$2.00 |
| Data Transfer | <5GB/mês | **$0.00** ✅ | ~$1.00 |
| **Total** | | **~$91.00/mês** | **~$109.00/mês** |

\* **Free Tier**: 750 horas/mês de t3.small grátis no primeiro ano = 1 instância 24/7

**💡 Economia vs configuração original**: $83/mês (47% de redução!)

### Ambiente Local (Docker)

- **Custo**: $0.00 (recursos locais)
- **Requisitos**: 4GB RAM, 20GB disco

### 📊 Destaques da Otimização:

✅ **1 node t3.small** (Free Tier: 750h/mês)  
✅ **API: 1-2 replicas** (mantém scaling!)  
✅ **HPA configurado** (escala em 70% CPU)  
✅ **1 LoadBalancer** (MailHog via ClusterIP)  
✅ **Resources otimizados** para t3.small  

**📖 Detalhes completos**: Ver [FREE_TIER_OPTIMIZATION.md](FREE_TIER_OPTIMIZATION.md)

## 🔧 Troubleshooting

### Problema 1: Cluster EKS não provisiona

**Sintoma:**
```
Error: error creating EKS Cluster: InvalidParameterException
```

**Solução:**
- Verificar se as subnets estão em AZs diferentes
- Verificar se as subnets têm as tags corretas:
  ```
  kubernetes.io/cluster/smart-workshop-dev-cluster = shared
  ```

### Problema 2: Pods não conectam ao RDS

**Sintoma:**
```
Error: Unable to connect to database
```

**Solução:**
- Verificar se o Security Group do RDS permite conexões do Security Group do EKS
- Verificar credenciais no Secret:
  ```bash
  kubectl get secret api-secret -n smart-workshop -o yaml
  ```

### Problema 3: LoadBalancer em "Pending"

**Sintoma:**
```
kubectl get svc
NAME              TYPE           EXTERNAL-IP   PORT(S)
api-service       LoadBalancer   <pending>     5180:xxxxx/TCP
```

**Solução:**
- Aguardar 5-10 minutos (AWS provisioning)
- Verificar logs do AWS Load Balancer Controller:
  ```bash
  kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
  ```

### Problema 4: Scheduler não funciona

**Sintoma:**
- Infraestrutura não para/inicia nos horários configurados

**Solução:**
- Verificar timezone do workflow (deve usar America/Sao_Paulo)
- Verificar se secrets AWS estão configurados corretamente
- Revisar logs do workflow no GitHub Actions

### Problema 5: Docker Compose falha ao subir

**Sintoma:**
```
Error: Cannot connect to database
```

**Solução:**
- Verificar arquivo `.env.local`
- Verificar se portas 5180, 8025 e 1025 não estão em uso:
  ```bash
  lsof -i :5180
  lsof -i :8025
  ```

## 📚 Referências

- [Repositório da API](https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica)
- [Repositório Database](https://github.com/FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure-database)
- [Documentação AWS EKS](https://docs.aws.amazon.com/eks/)
- [Documentação Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Documentação Kubernetes](https://kubernetes.io/docs/home/)
- [MailHog Documentation](https://github.com/mailhog/MailHog)

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Licença

Este projeto é parte do curso SOAT da FIAP e é destinado para fins educacionais.

---

**Desenvolvido com ❤️ pela equipe FIAP SOAT Net**
