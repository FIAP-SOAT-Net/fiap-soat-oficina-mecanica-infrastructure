# 🚀 Guia AWS Fargate Spot para EKS

## 📌 O que é Fargate Spot?

**AWS Fargate Spot** é uma opção de computação serverless para Kubernetes que oferece até **70% de desconto** comparado ao Fargate normal. Ideal para:
- ✅ Projetos acadêmicos
- ✅ Ambientes de desenvolvimento
- ✅ Cargas de trabalho tolerantes a interrupções
- ✅ Workloads que podem ser restartados facilmente

## 💰 Comparação de Custos

### Opção 1: EC2 Node Groups (Anterior)
```
- EKS Control Plane: $73/mês
- 2x t3.medium nodes: $60/mês
- 2x Load Balancers: $36/mês
Total: $169/mês
```

### Opção 2: Fargate Spot (Atual)
```
- EKS Control Plane: $73/mês
- Fargate Spot (API): ~$10/mês (13h/dia, 1-2 pods)
- Fargate Spot (MailHog): ~$2/mês (13h/dia, 1 pod)
- 1x Load Balancer: $16/mês
Total: ~$101/mês
```

**Economia: ~$68/mês (40%)**

## 🎯 Configuração do Fargate Spot

### 1. Fargate Profile

O Terraform já cria automaticamente:
- Profile para namespace `smart-workshop`
- Profile para `kube-system` (CoreDNS)
- Label selector: `compute-type: fargate`

### 2. Labels nos Pods

Todos os pods devem ter o label:
```yaml
metadata:
  labels:
    compute-type: fargate
```

Já configurado em:
- ✅ `k8s/api/deployment.yaml`
- ✅ `k8s/mailhog/deployment.yaml`

### 3. Pricing Fargate Spot

Fargate Spot cobra por:
- **vCPU-hora**: $0.01233472 (70% de desconto)
- **GB-hora**: $0.00135054 (70% de desconto)

**Exemplo de cálculo (API Pod):**
```
API Pod: 0.25 vCPU, 512MB RAM
- vCPU cost: 0.25 * $0.01233472 = $0.00308/hora
- Memory cost: 0.5 * $0.00135054 = $0.00068/hora
Total por hora: $0.00376/hora

Por dia (13h): $0.049/dia
Por mês (20 dias úteis): $0.98/mês por pod
```

### 4. Spot Interrupções

Fargate Spot pode ser interrompido com **2 minutos de aviso**.

**Como lidar:**
- ✅ Kubernetes automaticamente reescheduling em outro nó
- ✅ HPA garante disponibilidade (min=1, max=2)
- ✅ Health checks reiniciam pods automaticamente
- ✅ Load Balancer redireciona tráfego
- ✅ Graceful shutdown configurado

## 📊 Recursos dos Pods

### API Pod
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"      # 0.25 vCPU
  limits:
    memory: "1Gi"
    cpu: "500m"
```

**Custo Fargate Spot:**
- Por hora: ~$0.0038
- Por dia (13h): ~$0.049
- Por mês: ~$10 (com 2 pods no máximo)

### MailHog Pod
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "50m"       # 0.05 vCPU
  limits:
    memory: "256Mi"
    cpu: "100m"
```

**Custo Fargate Spot:**
- Por hora: ~$0.0008
- Por dia (13h): ~$0.010
- Por mês: ~$2

## 🔧 Deploy com Fargate

### 1. Terraform Apply

```bash
cd terraform
terraform init
terraform apply
```

O Terraform criará:
- ✅ EKS Cluster
- ✅ Fargate Profiles
- ✅ IAM Roles
- ✅ Security Groups
- ✅ OIDC Provider

### 2. Patch CoreDNS (Automático)

O Terraform já executa:
```bash
kubectl patch deployment coredns \
  -n kube-system \
  --type json \
  -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
```

### 3. Deploy dos Pods

```bash
kubectl apply -f k8s/api/
kubectl apply -f k8s/mailhog/
```

### 4. Verificar

```bash
# Ver nodes Fargate
kubectl get nodes

# Ver pods
kubectl get pods -n smart-workshop -o wide

# Ver Fargate profiles
aws eks list-fargate-profiles --cluster-name smart-workshop-dev-cluster
```

## 🎛️ Acessar MailHog sem LoadBalancer

Como o MailHog usa ClusterIP (sem LoadBalancer público), use port-forward:

```bash
# Port-forward para acessar MailHog localmente
kubectl port-forward -n smart-workshop svc/mailhog-service 8025:8025

# Acessar no navegador
http://localhost:8025
```

**Ou via API interna:**
A API se conecta ao MailHog via DNS interno:
```
smtp-host: mailhog-service
smtp-port: 1025
```

## 📈 Auto Scaling com Fargate

### HPA Configurado

```yaml
minReplicas: 1
maxReplicas: 2
targetCPUUtilizationPercentage: 70
targetMemoryUtilizationPercentage: 80
```

**Como funciona:**
1. Tráfego aumenta → CPU/Memory > 70%/80%
2. HPA cria novo pod
3. Fargate provisiona automaticamente recursos
4. Load Balancer distribui tráfego
5. Tráfego diminui → Scale down para 1 pod

**Custo do Scale:**
- 1 pod: ~$0.0038/hora
- 2 pods: ~$0.0076/hora
- Apenas paga quando pods estão rodando

## ⏰ Scheduler Start/Stop

### Horários (já configurado)
- **Start**: 07:00 BRT (10:00 UTC)
- **Stop**: 20:00 BRT (23:00 UTC)

### Como funciona com Fargate

**Stop (20:00):**
```bash
kubectl scale deployment api-deployment -n smart-workshop --replicas=0
kubectl scale deployment mailhog-deployment -n smart-workshop --replicas=0
```
- Pods deletados
- **Custo: $0** durante o período parado

**Start (07:00):**
```bash
kubectl scale deployment api-deployment -n smart-workshop --replicas=1
kubectl scale deployment mailhog-deployment -n smart-workshop --replicas=1
```
- Fargate provisiona novos pods (~2min)
- Cobrança retoma

## 💡 Dicas para Otimizar Custos

### 1. Reduzir recursos dos pods
```yaml
# API
requests:
  cpu: "200m"      # ao invés de 250m
  memory: "384Mi"  # ao invés de 512Mi
```

### 2. Schedule mais agressivo
```yaml
# Start 08:00, Stop 18:00 (10h/dia)
cron: '0 11 * * 1-5'  # Start
cron: '0 21 * * 1-5'  # Stop
```

### 3. Fargate Spot Savings Plan
- Commit de 1 ano: 20% adicional de desconto
- Commit de 3 anos: 50% adicional de desconto

### 4. Remover Load Balancer (avançado)
- Usar Ingress Controller
- Ou apenas port-forward para dev

## 🆘 Troubleshooting Fargate

### Pods não schedulam

**Problema:** Pods ficam em Pending
**Solução:**
```bash
# Verificar Fargate profiles
aws eks describe-fargate-profile \
  --cluster-name smart-workshop-dev-cluster \
  --fargate-profile-name smart-workshop-dev-app-profile

# Verificar label dos pods
kubectl get pods -n smart-workshop -o yaml | grep compute-type

# Verificar se subnet tem IPs disponíveis
aws ec2 describe-subnets --subnet-ids subnet-xxxxx
```

### CoreDNS não funciona

**Problema:** DNS resolution falha
**Solução:**
```bash
# Re-patch CoreDNS
kubectl patch deployment coredns \
  -n kube-system \
  --type json \
  -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'

kubectl rollout restart -n kube-system deployment/coredns
```

### Pods interrompidos frequentemente

**Problema:** Fargate Spot interrompe pods
**Solução:**
- Aumentar HPA minReplicas para 2 (alta disponibilidade)
- Considerar Fargate On-Demand para workloads críticos
- Implementar PodDisruptionBudget

## 📚 Referências

- [AWS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [EKS Fargate Documentation](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)
- [Fargate Spot Best Practices](https://aws.amazon.com/blogs/containers/aws-fargate-spot-now-generally-available/)

---

**Custo Total Mensal Estimado: ~$101**
- EKS Control Plane: $73
- Fargate Spot: $12-15
- Load Balancer: $16

**vs EC2 Nodes: ~$169**
**Economia: 40%** 🎉
