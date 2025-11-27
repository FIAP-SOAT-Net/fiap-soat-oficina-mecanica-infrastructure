# ⚡ Guia Rápido de Setup - GitHub Actions

Este documento contém os passos essenciais para configurar o deploy automático via GitHub Actions.

## 📋 Checklist de Setup (Execute na ordem)

### ✅ 1. Backend do Terraform
```bash
./scripts/setup-terraform-backend.sh
```
Cria: Bucket S3 + Tabela DynamoDB para estado do Terraform

---

### ✅ 2. IAM Role para GitHub Actions
```bash
./scripts/setup-github-actions-role.sh
```
**IMPORTANTE**: Anote o Role ARN que aparecer no final!

Exemplo de output:
```
Role ARN: arn:aws:iam::344508262523:role/GitHubActionsEKSRole
```

---

### ✅ 3. Configurar Secrets no GitHub

Acesse: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

**Secrets obrigatórios:**

| Secret Name | Valor | Como obter |
|-------------|-------|------------|
| `AWS_ROLE_ARN` | `arn:aws:iam::344508262523:role/GitHubActionsEKSRole` | Output do script do passo 2 |
| `AWS_REGION` | `us-west-2` | Região fixa |
| `DB_PASSWORD` | Senha do RDS | Ver repo database |
| `RDS_ENDPOINT` | Endpoint do RDS | Comando abaixo 👇 |

**Obter RDS_ENDPOINT**:
```bash
aws rds describe-db-instances \
  --db-instance-identifier smart-workshop-dev-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

---

### ✅ 4. Executar Deploy

1. Acesse **Actions** → **🚀 Deploy Infrastructure**
2. Clique em **Run workflow**
3. Selecione branch `main`
4. Aguarde ~15-20 minutos

---

## 🔧 Troubleshooting

### Erro: "Access Denied" no Terraform Init
**Causa**: Role IAM sem permissões no bucket S3

**Solução**: Execute o script `setup-github-actions-role.sh` novamente

---

### Erro: "NoSuchBucket"
**Causa**: Bucket S3 do Terraform não existe

**Solução**: Execute o script `setup-terraform-backend.sh`

---

### Erro: "Unable to connect to database"
**Causa**: RDS_ENDPOINT incorreto ou vazio

**Solução**: 
1. Obtenha o endpoint correto com o comando acima
2. Atualize o secret `RDS_ENDPOINT` no GitHub
3. Re-execute o workflow

---

## 📝 Ordem Correta de Execução

```
1. setup-terraform-backend.sh
   ↓
2. setup-github-actions-role.sh
   ↓
3. Configurar secrets no GitHub
   ↓
4. Run workflow: 🚀 Deploy Infrastructure
```

---

## ⚠️ Avisos Importantes

- ⚠️ **Nunca commite** credenciais (senhas, ARNs) no repositório
- ⚠️ **Use secrets** do GitHub para informações sensíveis
- ⚠️ **Account ID** no seu caso: `344508262523`
- ⚠️ **Região AWS**: Sempre `us-west-2`

---

## 💰 Custos dos Recursos de Setup

| Recurso | Custo Mensal |
|---------|--------------|
| Bucket S3 (state) | ~$0.10 |
| DynamoDB (locks) | ~$0.40 |
| IAM Roles | $0.00 |
| **Total** | **~$0.50/mês** |

---

## 🎯 Próximos Passos Após Deploy

Após o workflow concluir com sucesso:

```bash
# Configurar kubectl local
aws eks update-kubeconfig --region us-west-2 --name smart-workshop-dev-cluster

# Verificar pods
kubectl get pods -n smart-workshop

# Obter URL da API
kubectl get svc api-service -n smart-workshop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

**Documentação completa**: Ver [README.md](../README.md)
