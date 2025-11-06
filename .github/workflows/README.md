# 🚀 GitHub Actions Workflows

Este projeto inclui workflows automatizados do GitHub Actions para deploy e gerenciamento da infraestrutura e aplicações na AWS.

## 📋 Pré-requisitos

Antes de usar os workflows, configure os seguintes **Secrets** no repositório GitHub:

### Secrets Necessários

1. **AWS_ACCESS_KEY_ID**: Access Key ID da AWS
2. **AWS_SECRET_ACCESS_KEY**: Secret Access Key da AWS
3. **AWS_SESSION_TOKEN**: Session Token da AWS (para AWS Academy)

### Como configurar os Secrets

1. Vá para **Settings** → **Secrets and variables** → **Actions**
2. Clique em **New repository secret**
3. Adicione cada um dos secrets listados acima

## 🛠️ Workflows Disponíveis

### 1. 🚀 Complete Deployment Pipeline

**Arquivo:** `.github/workflows/deploy-complete.yml`

Este é o workflow principal que permite fazer o deploy completo da solução:

- ✅ Deploy da infraestrutura (Terraform)
- ✅ Deploy das aplicações (Kubernetes)
- ✅ Configuração automática do banco de dados
- ✅ Testes de saúde da API

**Como usar:**

1. Vá para **Actions** → **Complete Deployment Pipeline**
2. Clique em **Run workflow**
3. Configure os parâmetros:
   - **Environment**: `production`
   - **Deploy Infrastructure**: ✅ (marque se quiser criar a infraestrutura)
   - **Deploy Applications**: ✅ (marque se quiser fazer deploy das apps)
   - **Database password**: `workshop123` (ou outra senha de sua escolha)

### 2. 🏗️ Deploy Infrastructure (Terraform)

**Arquivo:** `.github/workflows/deploy-infrastructure.yml`

Deploy apenas da infraestrutura AWS usando Terraform:

**Parâmetros:**

- **Environment**: Ambiente de deploy (`production`)
- **Action**: `plan`, `apply`, ou `destroy`
- **Database password**: Senha do banco de dados

### 3. 🚀 Deploy Applications (Kubernetes)

**Arquivo:** `.github/workflows/deploy-applications.yml`

Deploy apenas das aplicações Kubernetes (requer infraestrutura já criada):

**Parâmetros:**

- **Environment**: Ambiente de deploy (`production`)
- **Cluster Name**: Nome do cluster EKS
- **RDS Endpoint**: Endpoint do banco RDS (com porta)

### 4. 💥 Destroy Infrastructure

**Arquivo:** `.github/workflows/destroy-infrastructure.yml`

Destroi completamente a infraestrutura AWS:

**Parâmetros:**

- **Environment**: Ambiente a ser destruído
- **Confirm Destroy**: Digite exatamente `DESTROY` para confirmar
- **Database password**: Senha do banco (necessária para destruição)

## 🔄 Fluxo de Trabalho Recomendado

### Deploy Inicial

1. Execute o **Complete Deployment Pipeline** com ambas as opções marcadas
2. Aguarde a conclusão (15-20 minutos)
3. Acesse as URLs fornecidas no resumo do workflow

### Deploy de Atualizações

1. Para mudanças na infraestrutura: Execute **Deploy Infrastructure**
2. Para mudanças nas aplicações: Execute **Deploy Applications**

### Limpeza

1. Execute **Destroy Infrastructure** quando quiser remover tudo

## 📊 Outputs dos Workflows

Após a execução bem-sucedida, os workflows fornecem:

### Infraestrutura

- **Cluster ID**: Nome do cluster EKS criado
- **RDS Endpoint**: Endpoint do banco de dados
- **VPC ID**: ID da VPC criada

### Aplicações

- **API URL**: URL da API REST
- **API Health**: Endpoint de health check
- **MailHog URL**: Interface do MailHog para emails

## 🧪 Validação

Os workflows incluem validações automáticas:

- ✅ Health check da API
- ✅ Verificação de pods em execução
- ✅ Status dos LoadBalancers
- ✅ Conectividade com o banco de dados

## 🔧 Troubleshooting

### Problemas Comuns

1. **Erro de credenciais AWS**: Verifique se os secrets estão configurados corretamente
2. **Timeout na criação**: A infraestrutura pode levar até 20 minutos para ficar pronta
3. **RDS não acessível**: Aguarde alguns minutos após a criação da infraestrutura

### Logs e Debugging

- Todos os steps dos workflows têm logs detalhados
- Use o **Summary** do workflow para ver informações resumidas
- Para debug avançado, execute steps individuais localmente

## 📝 Notas Importantes

- Os workflows são configurados para execução manual (`workflow_dispatch`)
- Todos os recursos são criados na região `us-east-1`
- Os LoadBalancers podem levar alguns minutos para ficarem disponíveis
- O banco de dados é inicializado automaticamente com tabelas e dados de exemplo

## 🆘 Suporte

Em caso de problemas:

1. Verifique os logs do workflow no GitHub Actions
2. Consulte o `DEPLOY_GUIDE.md` para deploy manual
3. Verifique se as credenciais AWS estão válidas
4. Para AWS Academy, atualize as credenciais a cada nova sessão
