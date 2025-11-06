# Kubernetes Infrastructure for Smart Mechanical Workshop

Este diretório contém toda a configuração de infraestrutura Kubernetes para o projeto Smart Mechanical Workshop, utilizando **Kustomize** para gerenciamento de múltiplos ambientes.

## 📋 Índice

- [Arquitetura](#arquitetura)
- [Estrutura de Arquivos](#estrutura-de-arquivos)
- [Ambientes Configurados](#ambientes-configurados)
- [Pré-requisitos](#pré-requisitos)
- [Configuração por Ambiente](#configuração-por-ambiente)
- [Deploy](#deploy)
- [Acesso aos Serviços](#acesso-aos-serviços)
- [Monitoramento e Debug](#monitoramento-e-debug)
- [Scripts Utilitários](#scripts-utilitários)

## 🏗️ Arquitetura

A infraestrutura Kubernetes foi projetada seguindo as melhores práticas de DevOps e separação de ambientes:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Development   │    │     Staging     │    │   Production    │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ API (External)  │    │ API (External)  │    │ API (External)  │
│ MySQL (External)│    │ MySQL (External)│    │ MySQL (Internal)│
│ MailHog (Ext.)  │    │ MailHog (Ext.)  │    │ MailHog (Int.)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Componentes

- **API**: Aplicação .NET 9.0 principal
- **MySQL 8.0**: Banco de dados principal
- **MailHog**: Servidor SMTP para desenvolvimento/teste
- **HPA**: Auto-scaling horizontal baseado em CPU
- **LoadBalancer**: Exposição externa dos serviços (dev/staging)
- **Ingress**: Roteamento HTTPS para produção

## 📁 Estrutura de Arquivos

```
k8s/
├── base/                           # Configurações base (reutilizáveis)
│   ├── kustomization.yaml         # Kustomize base
│   ├── namespace.yaml             # Namespace da aplicação
│   ├── configmap.yaml             # Configurações da aplicação
│   ├── secrets.yaml               # Senhas e chaves secretas
│   ├── pvc.yaml                   # Persistent Volume para MySQL
│   ├── mysql-deployment.yaml     # Deployment do MySQL
│   ├── api-deployment.yaml       # Deployment da API
│   ├── mailhog-deployment.yaml   # Deployment do MailHog
│   ├── services.yaml             # Services (ClusterIP base)
│   ├── hpa.yaml                  # Horizontal Pod Autoscaler
│   └── ingress.yaml              # Ingress base
├── overlays/                      # Configurações específicas por ambiente
│   ├── development/
│   │   └── kustomization.yaml    # Sobrescritas para desenvolvimento
│   ├── staging/
│   │   └── kustomization.yaml    # Sobrescritas para staging
│   └── production/
│       ├── kustomization.yaml    # Sobrescritas para produção
│       └── ingress.yaml          # Ingress com HTTPS
├── deploy.sh                     # Script de deploy automatizado
├── status.sh                     # Script para verificar status dos serviços
├── debug-api.sh                  # Script de debug para API
└── deploy_instructions.md        # Instruções de deploy
```

## 🌍 Ambientes Configurados

### Development
- **Namespace**: `smart-mechanical-workshop-dev`
- **Replicas**: 1 (API), 1 (MySQL)
- **Exposição**: LoadBalancer para API, MySQL e MailHog
- **HPA**: 1-3 replicas baseado em CPU
- **Finalidade**: Desenvolvimento local e testes

### Staging
- **Namespace**: `smart-mechanical-workshop-staging`
- **Replicas**: 2 (API), 1 (MySQL)
- **Exposição**: LoadBalancer para API, MySQL e MailHog
- **HPA**: 2-5 replicas baseado em CPU
- **Finalidade**: Testes de integração e validação

### Production
- **Namespace**: `smart-mechanical-workshop-prod`
- **Replicas**: 3 (API), 1 (MySQL)
- **Exposição**: LoadBalancer apenas para API (MySQL e MailHog internos)
- **HPA**: 3-20 replicas baseado em CPU
- **Ingress**: HTTPS com certificados SSL
- **Finalidade**: Ambiente de produção

## 🔧 Pré-requisitos

### Software Necessário
- **Kubernetes cluster** (minikube, kind, EKS, GKE, AKS, etc.)
- **kubectl** (versão 1.25+)
- **Kustomize** (incluído no kubectl 1.14+)

### Verificar Pré-requisitos
```bash
# Verificar cluster Kubernetes
kubectl cluster-info

# Verificar versão do kubectl
kubectl version --client

# Verificar Kustomize
kubectl kustomize --help
```

### Configuração de Storage Class (se necessário)
```bash
# Verificar storage classes disponíveis
kubectl get storageclass

# Se não houver storage class padrão, configure uma
# Exemplo para minikube:
minikube addons enable default-storageclass
```

## ⚙️ Configuração por Ambiente

### Imagens Docker

| Ambiente | API Tag | DB Tag |
|----------|---------|--------|
| Development | `latest` | `latest` |
| Staging | `staging-latest` | `staging-latest` |
| Production | `v1.0.0` | `v1.0.0` |

### Recursos Computacionais

| Ambiente | API CPU | API Memory | MySQL CPU | MySQL Memory |
|----------|---------|------------|-----------|--------------|
| Development | 100m-500m | 256Mi-512Mi | 100m-250m | 256Mi-512Mi |
| Staging | 200m-750m | 512Mi-1Gi | 100m-250m | 256Mi-512Mi |
| Production | 200m-1000m | 512Mi-1Gi | 200m-500m | 512Mi-1Gi |

### Configurações de Rede

| Ambiente | API Port | MySQL Port | MailHog Port |
|----------|----------|------------|--------------|
| Development | 5180 (External) | 3306 (External) | 8025 (External) |
| Staging | 5180 (External) | 3306 (External) | 8025 (External) |
| Production | 5180 (External) | 3306 (Internal) | 8025 (Internal) |

## 🚀 Deploy

### Deploy Automatizado

```bash
# Tornar scripts executáveis
chmod +x deploy.sh status.sh debug-api.sh

# Deploy para development
./deploy.sh development

# Deploy para staging
./deploy.sh staging

# Deploy para production
./deploy.sh production
```

### Deploy Manual com kubectl

```bash
# Development
kubectl apply -k overlays/development/

# Staging
kubectl apply -k overlays/staging/

# Production
kubectl apply -k overlays/production/
```

### Verificar Deploy

```bash
# Verificar status com script
./status.sh development

# Verificar manualmente
kubectl get all -n smart-mechanical-workshop-dev
```

## 🌐 Acesso aos Serviços

### K8S Development

Após o deploy, execute `./status.sh development` para obter as URLs:

```bash
# Exemplo de saída:
🔗 API: http://203.0.113.10:5180
❤️  Health: http://203.0.113.10:5180/health
📧 MailHog: http://203.0.113.15:8025
🗄️  MySQL: 203.0.113.20:3306
```

**Endpoints da API:**

- **Swagger**: `http://<API-IP>:5180/swagger`
- **Health Check**: `http://<API-IP>:5180/health`
- **Login**: `POST http://<API-IP>:5180/auth/login`

**MailHog Web Interface:**
- **URL**: `http://<MAILHOG-IP>:8025`

**Conexão MySQL:**

```bash
mysql -h <MYSQL-IP> -P 3306 -u workshopuser_dev -p
# Senha: workshop123
```

### K8S Staging

```bash
./status.sh staging
```

URLs similares ao development com prefixo `staging-`.

### K8S Production

```bash
./status.sh production
```

**Apenas API exposta externamente:**

- **API**: `http://<API-IP>:5180`
- **Ingress HTTPS**: `https://api.your-domain.com` (configurar DNS)

## 📊 Monitoramento e Debug

### Verificar Status dos Pods

```bash
# Status geral
kubectl get pods -n smart-mechanical-workshop-dev

# Detalhes de um pod específico
kubectl describe pod <pod-name> -n smart-mechanical-workshop-dev

# Logs da aplicação
kubectl logs -f <pod-name> -n smart-mechanical-workshop-dev
```

### Logs em Tempo Real

```bash
# Logs da API
kubectl logs -l app.kubernetes.io/name=smart-mechanical-workshop-api -n smart-mechanical-workshop-dev -f

# Logs do MySQL
kubectl logs -l app.kubernetes.io/name=mysql -n smart-mechanical-workshop-dev -f

# Eventos do namespace
kubectl get events -n smart-mechanical-workshop-dev --sort-by='.lastTimestamp'
```

### Debug da API

```bash
# Script automatizado de debug
./debug-api.sh

# Port forward para debug local (se necessário)
kubectl port-forward svc/dev-api-service 5180:5180 -n smart-mechanical-workshop-dev
```

### Verificar Auto-scaling

```bash
# Status do HPA
kubectl get hpa -n smart-mechanical-workshop-dev

# Detalhes do auto-scaling
kubectl describe hpa dev-api-hpa -n smart-mechanical-workshop-dev
```

## 🛠️ Scripts Utilitários

### deploy.sh

```bash
./deploy.sh <environment>
```

- Deploy automatizado para ambiente específico
- Aguarda LoadBalancer obter IP externo
- Mostra URLs de acesso dos serviços

### status.sh

```bash
./status.sh <environment>
```

- Verifica status de todos os serviços
- Mostra URLs de acesso externo
- Lista pods e seus estados

### debug-api.sh

```bash
./debug-api.sh
```
- Debug completo da API
- Logs atuais e anteriores
- Descrição detalhada do pod
- Status de ConfigMaps e Secrets

## 🔧 Troubleshooting

### Problemas Comuns

#### Pod em CrashLoopBackOff

```bash
# Ver logs do pod
kubectl logs <pod-name> -n <namespace> --previous

# Verificar configurações
kubectl describe pod <pod-name> -n <namespace>
```

#### LoadBalancer Pending

```bash
# Verificar se cluster suporta LoadBalancer
kubectl get svc -n <namespace>

# Para minikube, habilitar tunnel
minikube tunnel
```

#### Erro de Conexão MySQL

```bash
# Verificar se MySQL está rodando
kubectl get pods -l app.kubernetes.io/name=mysql -n <namespace>

# Testar conexão interna
kubectl exec -it <api-pod> -n <namespace> -- curl dev-mysql-service:3306
```

#### Imagem não encontrada

```bash
# Verificar se imagens existem no registry
docker pull igortessaro/smart-mechanical-workshop-api:latest

# Para minikube/kind, carregar imagem local
minikube image load igortessaro/smart-mechanical-workshop-api:latest
```

### Limpeza Completa

```bash
# Deletar ambiente específico
kubectl delete -k overlays/development/

# Deletar namespace (remove tudo)
kubectl delete namespace smart-mechanical-workshop-dev

# Limpar recursos órfãos
kubectl delete pv --all
```

## 📝 Configurações Avançadas

### Configurar Ingress com HTTPS

1. **Instalar cert-manager**:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

2. **Configurar ClusterIssuer**:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@domain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

3. **Atualizar DNS** para apontar para o Ingress Controller

### Configurar Monitoramento

```bash
# Instalar Prometheus e Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack
```

### Backup do MySQL

```bash
# Criar backup
kubectl exec <mysql-pod> -n <namespace> -- mysqldump -u root -p<password> workshopdb > backup.sql

# Restaurar backup
kubectl exec -i <mysql-pod> -n <namespace> -- mysql -u root -p<password> workshopdb < backup.sql
```

## 📚 Referências

- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [MySQL on Kubernetes](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/)
- [HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
