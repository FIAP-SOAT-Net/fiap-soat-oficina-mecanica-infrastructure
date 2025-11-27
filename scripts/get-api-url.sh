#!/bin/bash

# Script para obter a URL da API deployada no EKS
# Este script busca o endpoint do Load Balancer e testa a conectividade

set -e

AWS_REGION="us-west-2"
CLUSTER_NAME="smart-workshop-dev-cluster"
NAMESPACE="smart-workshop"
SERVICE_NAME="api-service"

echo "🔍 Buscando informações da API no EKS..."
echo ""

# 1. Verificar status do cluster
echo "1️⃣  Verificando cluster EKS..."
CLUSTER_STATUS=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_STATUS" == "NOT_FOUND" ]; then
    echo "   ❌ Cluster não encontrado. Certifique-se que o cluster foi criado."
    exit 1
elif [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    echo "   ⚠️  Cluster status: ${CLUSTER_STATUS}"
else
    echo "   ✅ Cluster ativo"
fi
echo ""

# 2. Buscar Network Load Balancers
echo "2️⃣  Buscando Network Load Balancers..."
NLB_INFO=$(aws elbv2 describe-load-balancers \
    --region "${AWS_REGION}" \
    --query 'LoadBalancers[?Type==`network`].{DNS:DNSName,ARN:LoadBalancerArn}' \
    --output json 2>/dev/null)

NLB_COUNT=$(echo "$NLB_INFO" | jq '. | length')

if [ "$NLB_COUNT" -eq 0 ]; then
    echo "   ❌ Nenhum Network Load Balancer encontrado"
    echo ""
    echo "💡 Possíveis causas:"
    echo "   - O deploy ainda não foi executado"
    echo "   - O AWS Load Balancer Controller não está instalado"
    echo "   - O serviço api-service não foi criado"
    echo ""
    echo "Execute o workflow: 🚀 Deploy Infrastructure"
    exit 1
fi

echo "   ✅ ${NLB_COUNT} Network Load Balancer(s) encontrado(s)"
echo ""

# 3. Para cada NLB, mostrar informações
echo "3️⃣  Informações dos Load Balancers:"
echo ""

for i in $(seq 0 $((NLB_COUNT - 1))); do
    DNS=$(echo "$NLB_INFO" | jq -r ".[$i].DNS")
    ARN=$(echo "$NLB_INFO" | jq -r ".[$i].ARN")
    
    echo "   Load Balancer #$((i + 1)):"
    echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   DNS: ${DNS}"
    
    # Buscar tags para identificar o serviço
    TAGS=$(aws elbv2 describe-tags --resource-arns "${ARN}" --region "${AWS_REGION}" --query 'TagDescriptions[0].Tags' --output json 2>/dev/null)
    SERVICE_TAG=$(echo "$TAGS" | jq -r '.[] | select(.Key=="kubernetes.io/service-name") | .Value' 2>/dev/null)
    
    if [ ! -z "$SERVICE_TAG" ]; then
        echo "   Service: ${SERVICE_TAG}"
    fi
    
    # Buscar listeners (portas)
    PORTS=$(aws elbv2 describe-listeners \
        --load-balancer-arn "${ARN}" \
        --region "${AWS_REGION}" \
        --query 'Listeners[].Port' \
        --output text 2>/dev/null)
    
    if [ ! -z "$PORTS" ]; then
        echo "   Portas: ${PORTS}"
        
        # Para cada porta, criar URL completa
        for PORT in $PORTS; do
            URL="http://${DNS}:${PORT}"
            echo ""
            echo "   🌐 URL da API: ${URL}"
            
            # Testar health check
            echo -n "   🔍 Testando health check... "
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "${URL}/health" 2>/dev/null || echo "000")
            
            if [ "$HTTP_CODE" == "200" ]; then
                echo "✅ Online (HTTP 200)"
                echo ""
                echo "   📋 Endpoints disponíveis:"
                echo "      • Health: ${URL}/health"
                echo "      • Swagger: ${URL}/swagger"
                echo "      • API Base: ${URL}"
            elif [ "$HTTP_CODE" == "000" ]; then
                echo "⏳ Aguardando (timeout)"
                echo "      Possíveis causas:"
                echo "      - Pods ainda inicializando"
                echo "      - Target group sem targets saudáveis"
                echo "      - Security group bloqueando tráfego"
            else
                echo "⚠️  HTTP ${HTTP_CODE}"
            fi
        done
    fi
    
    echo ""
done

# 4. Dicas adicionais
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Dicas:"
echo ""
echo "Para verificar status dos pods:"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "Para ver logs da API:"
echo "  kubectl logs -l app=api -n ${NAMESPACE} --tail=50"
echo ""
echo "Para verificar o serviço:"
echo "  kubectl get svc ${SERVICE_NAME} -n ${NAMESPACE}"
echo ""
echo "Para adicionar seu usuário ao cluster:"
echo "  Execute o workflow: 🔐 Add User to EKS Cluster"
echo ""
