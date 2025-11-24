# 🔐 Configuração GitHub Actions - Guia Completo

## 📋 Pré-requisitos

1. ✅ Conta AWS (243100982781)
2. ✅ Repositório GitHub criado
3. ✅ AWS CLI instalado localmente
4. ✅ Permissões de administrador no repositório

---

## 🔑 Passo 1: Criar OIDC Provider na AWS

O OIDC permite que o GitHub Actions se autentique na AWS **sem usar Access Keys** (mais seguro).

### 1.1. Criar OIDC Provider (via Console AWS)

1. Acesse: **IAM → Identity providers → Add provider**
2. Configure:
   ```
   Provider type: OpenID Connect
   Provider URL: https://token.actions.githubusercontent.com
   Audience: sts.amazonaws.com
   ```
3. Clique em **Add provider**

### 1.2. Ou via AWS CLI

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

---

## 👤 Passo 2: Criar IAM Role para GitHub Actions

### 2.1. Criar arquivo de trust policy

Crie o arquivo `github-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::243100982781:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure:*"
        }
      }
    }
  ]
}
```

**⚠️ IMPORTANTE:** Substitua `FIAP-SOAT-Net/fiap-soat-oficina-mecanica-infrastructure` pelo seu `org/repo` real!

### 2.2. Criar a role

```bash
aws iam create-role \
  --role-name GitHubActionsEKSRole \
  --assume-role-policy-document file://github-trust-policy.json
```

### 2.3. Criar policy customizada para Terraform State

```bash
# Criar arquivo de policy para S3 e DynamoDB
cat > /tmp/s3-terraform-state-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": "arn:aws:s3:::smart-workshop-infrastructure-terraform-state"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::smart-workshop-infrastructure-terraform-state/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-west-2:243100982781:table/smart-workshop-terraform-locks"
    }
  ]
}
EOF

# Criar a policy
aws iam create-policy \
  --policy-name TerraformStateAccessPolicy \
  --policy-document file:///tmp/s3-terraform-state-policy.json \
  --description "Policy for GitHub Actions to access Terraform state in S3 and DynamoDB"
```

### 2.4. Anexar policies necessárias

```bash
# Policy customizada para Terraform State
aws iam attach-role-policy \
  --role-name GitHubActionsEKSRole \
  --policy-arn arn:aws:iam::243100982781:policy/TerraformStateAccessPolicy

# Policy para EKS
aws iam attach-role-policy \
  --role-name GitHubActionsEKSRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

# Policy para EC2 (VPC, Security Groups)
aws iam attach-role-policy \
  --role-name GitHubActionsEKSRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

# Policy para IAM (criar roles do EKS)
aws iam attach-role-policy \
  --role-name GitHubActionsEKSRole \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

# Policy para Fargate
aws iam attach-role-policy \
  --role-name GitHubActionsEKSRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy
```

### 2.5. Copiar ARN da Role

```bash
aws iam get-role --role-name GitHubActionsEKSRole --query 'Role.Arn' --output text
```

**Exemplo de output:**
```
arn:aws:iam::243100982781:role/GitHubActionsEKSRole
```

**💾 Salve esse ARN, você vai usar no GitHub!**

---

## 🗄️ Passo 3: Criar S3 Bucket para Terraform State

```bash
# Criar bucket
aws s3api create-bucket \
  --bucket smart-workshop-infrastructure-terraform-state \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

# Habilitar versionamento (backup do state)
aws s3api put-bucket-versioning \
  --bucket smart-workshop-infrastructure-terraform-state \
  --versioning-configuration Status=Enabled

# Habilitar criptografia
aws s3api put-bucket-encryption \
  --bucket smart-workshop-infrastructure-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Bloquear acesso público
aws s3api put-public-access-block \
  --bucket smart-workshop-infrastructure-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

---

## 🔐 Passo 4: Configurar Secrets no GitHub

Acesse: **GitHub Repository → Settings → Secrets and variables → Actions → New repository secret**

### 4.1. Script automatizado (Recomendado)

Para facilitar, use o script que obtém todos os valores automaticamente:

```bash
# Executar script
./scripts/get-aws-values.sh

# O script irá:
# 1. Buscar VPC_ID automaticamente
# 2. Buscar SUBNET_IDS (2 subnets privadas em AZs diferentes)
# 3. Buscar RDS_ENDPOINT
# 4. Gerar JWT_SECRET_KEY
# 5. Obter AWS_ROLE_ARN
# 6. Exibir todos os valores formatados
# 7. Salvar em /tmp/github-secrets.txt
```

### 4.2. Secrets necessários

| Secret Name | Valor | Descrição |
|------------|-------|-----------|
| `AWS_REGION` | `us-west-2` | Região AWS |
| `AWS_ROLE_ARN` | `arn:aws:iam::243100982781:role/GitHubActionsEKSRole` | ARN da role criada no Passo 2.5 |
| `TF_STATE_BUCKET` | `smart-workshop-infrastructure-terraform-state` | Bucket do Terraform state |
| `TF_STATE_KEY` | `dev/terraform.tfstate` | Caminho do state file |
| `TF_STATE_REGION` | `us-west-2` | Região do bucket |
| `VPC_ID` | `vpc-00bb83a83a9813240` | ID da VPC (mesmo da infra de database) |
| `SUBNET_IDS` | `["subnet-xxx","subnet-yyy"]` | Array JSON com 2+ subnet IDs (AZs diferentes) ⚠️ |
| `RDS_ENDPOINT` | `seu-rds-endpoint.us-west-2.rds.amazonaws.com` | Endpoint do RDS MySQL |
| `DB_PASSWORD` | `sua-senha-segura` | Senha do banco (⚠️ NUNCA commitar!) |
| `JWT_SECRET_KEY` | `sua-chave-jwt-secreta` | Chave secreta para JWT da API |

**⚠️ IMPORTANTE:** O valor de `SUBNET_IDS` deve ser um **array JSON válido**:
- ✅ Correto: `["subnet-0abc123","subnet-0def456"]`
- ❌ Errado: `subnet-0abc123,subnet-0def456`
- ❌ Errado: `['subnet-0abc123','subnet-0def456']` (aspas simples)

### 4.3. Como obter os valores dos secrets (Manual)

#### VPC_ID e SUBNET_IDS (da infraestrutura de database)

```bash
# Obter VPC ID
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=smart-workshop-*" --query 'Vpcs[0].VpcId' --output text

# Listar TODAS as subnets da VPC (com detalhes)
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-00bb83a83a9813240" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Gerar formato JSON correto para SUBNET_IDS (primeiras 2 subnets):
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-00bb83a83a9813240" \
  --query 'Subnets[0:2].SubnetId' \
  --output json | jq -c .

# Exemplo de output (copie exatamente assim):
# ["subnet-0abc123def456","subnet-0xyz789ghi012"]

# ⚠️ IMPORTANTE: Escolha 2 subnets em AZs DIFERENTES (ex: us-west-2a e us-west-2b)
```

**⚠️ IMPORTANTE:** Copie o output do comando acima **EXATAMENTE** como aparece, incluindo os colchetes e aspas duplas!

#### RDS_ENDPOINT

```bash
# Obter endpoint do RDS
aws rds describe-db-instances \
  --db-instance-identifier smart-workshop-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

#### JWT_SECRET_KEY

```bash
# Gerar uma chave segura aleatória
openssl rand -base64 32
```

### 4.4. Como adicionar cada secret

1. Clique em **New repository secret**
2. Preencha **Name** e **Secret**
3. Clique em **Add secret**
4. Repita para todos os secrets acima

**Exemplo prático:**

```
Name:   SUBNET_IDS
Secret: ["subnet-0abc123def456789","subnet-0xyz789ghi012345"]
        ↑ Copie EXATAMENTE assim, com colchetes e aspas duplas

Name:   VPC_ID  
Secret: vpc-00bb83a83a9813240
        ↑ Apenas o ID, sem aspas

Name:   RDS_ENDPOINT
Secret: smart-workshop-db.abc123.us-west-2.rds.amazonaws.com
        ↑ Apenas o hostname, sem porta ou protocolo
```

---

## 📊 Passo 5: Configurar Variables (opcional)

Acesse: **Settings → Secrets and variables → Actions → Variables → New repository variable**

| Variable Name | Valor | Descrição |
|--------------|-------|-----------|
| `AWS_ACCOUNT_ID` | `243100982781` | ID da conta AWS |
| `CLUSTER_NAME` | `smart-workshop-dev-cluster` | Nome do cluster EKS |
| `NAMESPACE` | `smart-workshop` | Namespace do Kubernetes |
| `ENVIRONMENT` | `dev` | Ambiente (dev/staging/prod) |

**💡 Diferença:** Secrets são criptografados e ocultos. Variables são visíveis nos logs.

---

## 🚀 Passo 6: Testar o Deploy

### 6.1. Fazer commit e push

```bash
git add .
git commit -m "feat: Add Fargate Spot infrastructure with GitHub Actions"
git push origin main
```

### 6.2. Executar workflow manualmente

1. Acesse: **Actions → Deploy to AWS EKS → Run workflow**
2. Selecione branch `main`
3. Clique em **Run workflow**

### 6.3. Acompanhar logs

- ✅ **Configure AWS Credentials**: Deve autenticar via OIDC
- ✅ **Terraform Init**: Deve conectar ao S3 backend
- ✅ **Terraform Plan**: Deve mostrar recursos a criar
- ✅ **Terraform Apply**: Deve criar EKS + Fargate
- ✅ **Deploy to Kubernetes**: Deve aplicar manifests

---

## 🛠️ Passo 7: Workflows Disponíveis

### 7.1. Deploy (Manual ou Push)

```yaml
# Trigger manual
Actions → Deploy to AWS EKS → Run workflow

# Trigger automático
git push origin main  # Deploy automático
```

### 7.2. Destroy (Manual)

```yaml
Actions → Destroy AWS EKS Infrastructure → Run workflow
```

**⚠️ CUIDADO:** Isso deleta **TODA** a infraestrutura!

### 7.3. Start/Stop Scheduler (Automático)

```yaml
# Já configurado para rodar automaticamente:
- Start: Segunda a Sexta, 07:00 BRT (10:00 UTC)
- Stop:  Segunda a Sexta, 20:00 BRT (23:00 UTC)
```

**💡 Para desabilitar:** Comente as linhas `schedule:` em `.github/workflows/start-stop-scheduler.yml`

---

## 🔍 Troubleshooting

### Erro: "Error assuming role"

**Causa:** OIDC Provider ou Role mal configurada

**Solução:**
```bash
# Verificar OIDC Provider
aws iam list-open-id-connect-providers

# Verificar Role
aws iam get-role --role-name GitHubActionsEKSRole

# Verificar trust policy
aws iam get-role --role-name GitHubActionsEKSRole --query 'Role.AssumeRolePolicyDocument'
```

### Erro: "Backend initialization failed"

**Causa:** Bucket S3 não existe ou sem permissão

**Solução:**
```bash
# Verificar bucket
aws s3 ls s3://smart-workshop-infrastructure-terraform-state

# Verificar permissões da role
aws iam list-attached-role-policies --role-name GitHubActionsEKSRole
```

### Erro: "Access Denied" ao criar EKS

**Causa:** Role sem permissões suficientes

**Solução:**
```bash
# Anexar policy adicional
aws iam attach-role-policy \
  --role-name GitHubActionsEKSRole \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

### Workflow não dispara automaticamente

**Causa:** Branch protection ou permissões

**Solução:**
1. Acesse: **Settings → Actions → General**
2. Em **Workflow permissions**, selecione: **Read and write permissions**
3. Marque: **Allow GitHub Actions to create and approve pull requests**

---

## 📋 Checklist Final

Antes de rodar o deploy, confirme:

- [ ] OIDC Provider criado na AWS
- [ ] IAM Role `GitHubActionsEKSRole` criada
- [ ] Policies anexadas à role (EKS, EC2, IAM, Fargate, S3)
- [ ] S3 Bucket criado com versionamento e criptografia
- [ ] Todos os 10 secrets configurados no GitHub
- [ ] VPC_ID e SUBNET_IDS obtidos da infraestrutura de database
- [ ] Trust policy da role aponta para o repositório correto
- [ ] Workflows commitados e pushed para o repositório
- [ ] Permissões do GitHub Actions configuradas (read/write)

---

## 🎯 Ordem de Execução Recomendada

### Primeiro Deploy (Infrastructure)

```bash
# 1. Deploy da infraestrutura
Actions → Deploy to AWS EKS → Run workflow
# Aguardar ~15-20 minutos (EKS cluster creation)
```

### Verificação

```bash
# 2. Configurar kubectl localmente
aws eks update-kubeconfig --region us-west-2 --name smart-workshop-dev-cluster

# 3. Verificar nodes Fargate
kubectl get nodes

# 4. Verificar pods
kubectl get pods -n smart-workshop

# 5. Verificar services
kubectl get svc -n smart-workshop

# 6. Obter URL do Load Balancer
kubectl get svc api-service -n smart-workshop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Testar API

```bash
# Health check
curl http://<LOAD_BALANCER_URL>/health

# Swagger UI
open http://<LOAD_BALANCER_URL>/swagger
```

---

## 💰 Monitorar Custos

### AWS Cost Explorer

1. Acesse: **AWS Console → Cost Management → Cost Explorer**
2. Filtre por:
   - Service: EKS, Fargate, EC2 (Load Balancer)
   - Tag: `Environment: dev`

### Estimativa mensal

```
EKS Control Plane: $73/mês
Fargate Spot: ~$12-15/mês
Load Balancer: ~$16/mês
Total: ~$101-104/mês
```

### Alarme de custo (opcional)

```bash
# Criar alarme para $150/mês
aws cloudwatch put-metric-alarm \
  --alarm-name eks-cost-alarm \
  --alarm-description "Alert when EKS cost exceeds $150" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 150 \
  --comparison-operator GreaterThanThreshold
```

---

## 📚 Referências

- [GitHub OIDC com AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [EKS Fargate](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

**✅ Pronto! Agora você pode fazer deploy da infraestrutura direto do GitHub Actions!**
