#!/bin/bash

# Script para obter informações da API no EKS
# Usage: ./scripts/get-api-info.sh

set -e

echo "======================================"
echo "  🚀 Informações da API no EKS"
echo "======================================"
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurar kubectl
echo -e "${YELLOW}📝 Configurando kubectl...${NC}"
aws eks update-kubeconfig --region us-west-2 --name smart-workshop-dev-cluster
echo ""

# Obter URL pública da API
echo -e "${YELLOW}🌐 Obtendo URL pública da API...${NC}"
API_URL=$(kubectl get svc api-service -n smart-workshop -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$API_URL" ]; then
  echo -e "${YELLOW}⚠️  Load Balancer ainda não tem hostname. Aguarde alguns minutos...${NC}"
  echo ""
  kubectl get svc api-service -n smart-workshop
else
  echo -e "${GREEN}✅ URL da API: http://$API_URL:5180${NC}"
  echo ""
  
  echo -e "${BLUE}📊 Endpoints disponíveis:${NC}"
  echo "  - Health Check: http://$API_URL:5180/health"
  echo "  - Swagger UI:   http://$API_URL:5180/swagger"
  echo "  - API Docs:     http://$API_URL:5180/swagger/v1/swagger.json"
  echo ""
fi

# Status dos pods
echo -e "${YELLOW}📦 Status dos Pods:${NC}"
kubectl get pods -n smart-workshop -o wide
echo ""

# Detalhes do serviço
echo -e "${YELLOW}🔗 Detalhes do Serviço API:${NC}"
kubectl get svc api-service -n smart-workshop -o wide
echo ""

# MailHog (se precisar acessar)
echo -e "${YELLOW}📧 MailHog (acesso local via port-forward):${NC}"
echo "  kubectl port-forward -n smart-workshop svc/mailhog-service 8025:8025"
echo "  Depois acesse: http://localhost:8025"
echo ""

# Comandos úteis
echo "======================================"
echo "  📚 Comandos Úteis"
echo "======================================"
echo ""
echo -e "${BLUE}Ver logs da API:${NC}"
echo "  kubectl logs -n smart-workshop -l app=api -f"
echo ""
echo -e "${BLUE}Ver logs dos últimos 100 linhas:${NC}"
echo "  kubectl logs -n smart-workshop -l app=api --tail=100"
echo ""
echo -e "${BLUE}Ver logs de um pod específico:${NC}"
echo "  kubectl logs -n smart-workshop <POD_NAME> -f"
echo ""
echo -e "${BLUE}Entrar no pod (troubleshooting):${NC}"
echo "  kubectl exec -it -n smart-workshop <POD_NAME> -- /bin/sh"
echo ""
echo -e "${BLUE}Ver eventos do namespace:${NC}"
echo "  kubectl get events -n smart-workshop --sort-by='.lastTimestamp'"
echo ""
echo -e "${BLUE}Restart da API:${NC}"
echo "  kubectl rollout restart deployment/api-deployment -n smart-workshop"
echo ""
echo -e "${BLUE}Escalar API (2 réplicas):${NC}"
echo "  kubectl scale deployment api-deployment -n smart-workshop --replicas=2"
echo ""
echo -e "${BLUE}Ver métricas (CPU/Memory):${NC}"
echo "  kubectl top pods -n smart-workshop"
echo ""

# Testar health check (se URL disponível)
if [ ! -z "$API_URL" ]; then
  echo "======================================"
  echo "  🏥 Testando Health Check"
  echo "======================================"
  echo ""
  
  echo -e "${YELLOW}Fazendo requisição para /health...${NC}"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$API_URL:5180/health --connect-timeout 5 || echo "000")
  
  if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✅ API está saudável! (HTTP $HTTP_CODE)${NC}"
  else
    echo -e "${YELLOW}⚠️  Health check falhou (HTTP $HTTP_CODE)${NC}"
    echo "   Verifique os logs: kubectl logs -n smart-workshop -l app=api --tail=50"
  fi
  echo ""
fi

echo "======================================"
echo ""
