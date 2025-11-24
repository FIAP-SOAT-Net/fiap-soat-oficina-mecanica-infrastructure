#!/bin/bash

# Script para obter URL da API via AWS CLI (sem precisar de kubectl)
# Usage: ./scripts/get-api-url-simple.sh

set -e

echo "======================================"
echo "  🌐 Obter URL da API (via AWS)"
echo "======================================"
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔍 Buscando Load Balancer da API...${NC}"
echo ""

# Obter Load Balancers com tag do cluster
LBS=$(aws elbv2 describe-load-balancers \
  --region us-west-2 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-smartwor`) || contains(Tags[?Key==`kubernetes.io/cluster/smart-workshop-dev-cluster`].Value, `owned`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' \
  --output table 2>/dev/null || echo "")

if [ -z "$LBS" ]; then
  echo -e "${YELLOW}⚠️  Procurando por qualquer Load Balancer recente...${NC}"
  echo ""
  
  # Buscar todos os LBs e filtrar por data
  aws elbv2 describe-load-balancers \
    --region us-west-2 \
    --query 'LoadBalancers[?CreatedTime>=`2024-11-24`].{Name:LoadBalancerName,DNS:DNSName,State:State.Code,Created:CreatedTime}' \
    --output table
else
  echo "$LBS"
fi

echo ""
echo "======================================"
echo "  📋 Como obter a URL via AWS Console"
echo "======================================"
echo ""
echo "1. Acesse: https://console.aws.amazon.com/ec2/v2/home?region=us-west-2#LoadBalancers:"
echo "2. Procure por Load Balancer com nome contendo 'k8s-smartwor'"
echo "3. Copie o 'DNS name'"
echo "4. A URL da API será: http://<DNS_NAME>:5180"
echo ""
echo -e "${BLUE}Endpoints disponíveis:${NC}"
echo "  - Health Check: http://<DNS_NAME>:5180/health"
echo "  - Swagger UI:   http://<DNS_NAME>:5180/swagger"
echo ""

echo "======================================"
echo "  📝 Obter Logs via AWS CloudWatch"
echo "======================================"
echo ""
echo "1. Acesse: https://console.aws.amazon.com/cloudwatch/home?region=us-west-2#logsV2:log-groups"
echo "2. Procure por: /aws/eks/smart-workshop-dev-cluster"
echo "3. Dentro, acesse: cluster → smart-workshop"
echo ""
echo "Ou via CLI:"
echo "  aws logs tail /aws/containerinsights/smart-workshop-dev-cluster/application --follow"
echo ""

echo "======================================"
echo "  🔐 Dar acesso ao seu usuário (Opcional)"
echo "======================================"
echo ""
echo "Para usar kubectl localmente, execute:"
echo "  ./scripts/add-user-to-eks.sh"
echo ""
echo "Depois aplique o ConfigMap via AWS CloudShell (instruções no script)"
echo ""
