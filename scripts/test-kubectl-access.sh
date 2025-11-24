#!/bin/bash

# Script para testar acesso ao cluster após execução do workflow
# Usage: ./scripts/test-kubectl-access.sh

set -e

echo "======================================"
echo "  🔐 Testando Acesso ao Cluster EKS"
echo "======================================"
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}1️⃣  Testando acesso ao cluster...${NC}"
if kubectl get nodes &> /dev/null; then
  echo -e "${GREEN}   ✅ Acesso funcionando!${NC}"
  echo ""
  kubectl get nodes
else
  echo -e "${RED}   ❌ Sem acesso ao cluster${NC}"
  echo ""
  echo -e "${YELLOW}Possíveis soluções:${NC}"
  echo "1. Execute o workflow 'Add User to EKS Cluster' no GitHub Actions"
  echo "2. Aguarde 1-2 minutos para as permissões propagarem"
  echo "3. Execute: aws eks update-kubeconfig --region us-west-2 --name smart-workshop-dev-cluster"
  echo ""
  exit 1
fi

echo ""
echo -e "${BLUE}2️⃣  Verificando pods da API...${NC}"
kubectl get pods -n smart-workshop -l app=api
echo ""

echo -e "${BLUE}3️⃣  Verificando serviço LoadBalancer...${NC}"
kubectl get svc -n smart-workshop api-service
echo ""

echo -e "${BLUE}4️⃣  Obtendo URL da API...${NC}"
LB_HOSTNAME=$(kubectl get svc api-service -n smart-workshop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$LB_HOSTNAME" ]; then
  echo -e "${YELLOW}   ⏳ Load Balancer ainda sendo provisionado...${NC}"
  echo ""
  echo "Execute novamente em 2-3 minutos:"
  echo "  ./scripts/test-kubectl-access.sh"
else
  echo -e "${GREEN}   ✅ URL da API encontrada!${NC}"
  echo ""
  echo "======================================"
  echo -e "  ${GREEN}🌐 URL da API${NC}"
  echo "======================================"
  echo ""
  echo -e "${BLUE}Base URL:${NC}"
  echo "  http://$LB_HOSTNAME:5180"
  echo ""
  echo -e "${BLUE}Endpoints disponíveis:${NC}"
  echo "  - Health:  http://$LB_HOSTNAME:5180/health"
  echo "  - Swagger: http://$LB_HOSTNAME:5180/swagger"
  echo ""
  
  # Testar health endpoint
  echo -e "${BLUE}5️⃣  Testando health endpoint...${NC}"
  if curl -s -f -m 5 "http://$LB_HOSTNAME:5180/health" > /dev/null 2>&1; then
    echo -e "${GREEN}   ✅ API respondendo!${NC}"
    echo ""
    curl -s "http://$LB_HOSTNAME:5180/health" | jq . || curl -s "http://$LB_HOSTNAME:5180/health"
  else
    echo -e "${YELLOW}   ⏳ API ainda inicializando...${NC}"
    echo ""
    echo "Verifique os logs:"
    echo "  kubectl logs -n smart-workshop -l app=api --tail=50"
  fi
fi

echo ""
echo "======================================"
echo -e "  ${GREEN}📋 Comandos Úteis${NC}"
echo "======================================"
echo ""
echo "Ver logs da API:"
echo "  kubectl logs -n smart-workshop -l app=api -f"
echo ""
echo "Ver pods:"
echo "  kubectl get pods -n smart-workshop"
echo ""
echo "Descrever pod:"
echo "  kubectl describe pod -n smart-workshop -l app=api"
echo ""
echo "MailHog (emails):"
echo "  kubectl port-forward -n smart-workshop svc/mailhog-service 8025:8025"
echo "  Acesse: http://localhost:8025"
echo ""
