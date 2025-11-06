#!/bin/bash

# Script para preparar configurações AWS e fazer deploy
# Usage: ./deploy-aws.sh

set -e

echo "🚀 Iniciando deploy AWS..."

# 1. Obter endpoint do RDS do Terraform
echo "📋 Obtendo informações da infraestrutura..."
cd terraform/environments/production
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
echo "RDS Endpoint: $RDS_ENDPOINT"

# 2. Voltar para raiz e preparar configurações
cd ../../../
TEMP_DIR=$(mktemp -d)

# 3. Copiar overlays e substituir placeholder
cp -r k8s/overlays/aws-production/* $TEMP_DIR/
sed -i '' "s/RDS_ENDPOINT_PLACEHOLDER/$RDS_ENDPOINT/g" $TEMP_DIR/configmap-aws.yaml

# 4. Criar namespace se não existir
kubectl create namespace smart-mechanical-workshop --dry-run=client -o yaml | kubectl apply -f -

# 5. Aplicar configurações
echo "📦 Aplicando configurações..."
kubectl apply -f $TEMP_DIR/configmap-aws.yaml

# Criar secret necessário
kubectl create secret generic smart-mechanical-workshop-secrets \
  --from-literal=MYSQL_PASSWORD="Academic123" \
  --from-literal=JWT_KEY="your-very-secure-and-long-key-1234567890" \
  -n smart-mechanical-workshop --dry-run=client -o yaml | kubectl apply -f -

# 6. Fazer deploy das aplicações
echo "🚀 Fazendo deploy das aplicações..."

# Aplicar namespace
kubectl apply -f k8s/base/namespace.yaml

# Deploy MailHog
kubectl apply -f k8s/base/mailhog-deployment.yaml

# Deploy API com recursos otimizados
kubectl apply -f k8s/base/api-deployment.yaml

# Aguardar deployments serem criados
sleep 5

# Aplicar patch de recursos da API para economizar custos
kubectl patch deployment api-deployment -n smart-mechanical-workshop -p '{"spec":{"replicas":1,"template":{"spec":{"containers":[{"name":"api","resources":{"requests":{"memory":"128Mi","cpu":"100m"},"limits":{"memory":"256Mi","cpu":"200m"}}}]}}}}'

# Aplicar services LoadBalancer
kubectl apply -f $TEMP_DIR/services-loadbalancer.yaml

# 7. Aguardar deployments
echo "⏳ Aguardando pods ficarem prontos..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=api -n smart-mechanical-workshop --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=mail-testing -n smart-mechanical-workshop --timeout=300s

# 8. Mostrar status e endpoints
echo "📊 Status do deployment:"
kubectl get all -n smart-mechanical-workshop

echo "🌐 Endpoints externos:"
kubectl get services -n smart-mechanical-workshop

# Limpar arquivos temporários
rm -rf $TEMP_DIR

echo "✅ Deploy concluído!"
