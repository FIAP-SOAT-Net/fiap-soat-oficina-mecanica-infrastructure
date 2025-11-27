#!/bin/bash

# Script de diagnóstico para API no EKS com Fargate
set -e

AWS_REGION="us-west-2"
NAMESPACE="smart-workshop"

echo "🔍 Diagnóstico da API no EKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Status dos pods
echo "1️⃣  Status dos Pods:"
kubectl get pods -n $NAMESPACE -o wide
echo ""

# 2. Serviço e LoadBalancer
echo "2️⃣  Serviço LoadBalancer:"
kubectl get svc api-service -n $NAMESPACE
API_URL=$(kubectl get svc api-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo ""
echo "   URL: http://${API_URL}:5180"
echo ""

# 3. Detalhes do serviço
echo "3️⃣  Detalhes do Serviço:"
kubectl describe svc api-service -n $NAMESPACE | grep -E "Type:|Annotations:|Port:|TargetPort:|Endpoints:|LoadBalancer"
echo ""

# 4. Target Groups
echo "4️⃣  Target Groups do NLB:"
aws elbv2 describe-target-groups --region $AWS_REGION \
    --query 'TargetGroups[?contains(TargetGroupName, `smartwor`)].{Name:TargetGroupName,Type:TargetType,Port:Port,Protocol:Protocol,HealthProtocol:HealthCheckProtocol}' \
    --output table
echo ""

# 5. Obter ARN do target group mais recente
TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
    --query 'TargetGroups[?contains(TargetGroupName, `smartwor-apiservi`)].TargetGroupArn' \
    --output text | tail -1)

if [ ! -z "$TG_ARN" ]; then
    echo "5️⃣  Health Status dos Targets:"
    aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region $AWS_REGION \
        --query 'TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State,Reason:TargetHealth.Reason}' \
        --output table
    echo ""
fi

# 6. Security Group do Cluster
echo "6️⃣  Security Group Rules (Ingress):"
SG_ID=$(kubectl get svc api-service -n $NAMESPACE -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-security-groups}' 2>/dev/null || echo "")

if [ -z "$SG_ID" ]; then
    # Pegar do cluster
    SG_ID=$(aws eks describe-cluster --name smart-workshop-dev-cluster --region $AWS_REGION \
        --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
fi

if [ ! -z "$SG_ID" ]; then
    aws ec2 describe-security-group-rules --region $AWS_REGION \
        --filters "Name=group-id,Values=$SG_ID" \
        --query 'SecurityGroupRules[?IsEgress==`false`].{Port:FromPort,Protocol:IpProtocol,Source:CidrIpv4,Desc:Description}' \
        --output table | head -15
else
    echo "   Security Group ID não encontrado"
fi
echo ""

# 7. Teste de conectividade
echo "7️⃣  Teste de Conectividade:"
echo "   Testando: http://${API_URL}:5180/health"
echo -n "   Status: "

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://${API_URL}:5180/health" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ Online (HTTP 200)"
    echo ""
    echo "   🌐 API está acessível!"
    echo "   • Health: http://${API_URL}:5180/health"
    echo "   • Swagger: http://${API_URL}:5180/swagger"
elif [ "$HTTP_CODE" == "000" ]; then
    echo "❌ Timeout/Connection refused"
    echo ""
    echo "   ⚠️  Possíveis problemas:"
    echo "   1. Target group com target type 'instance' em vez de 'ip' (Fargate incompatível)"
    echo "   2. Security Group bloqueando tráfego na porta 5180"
    echo "   3. Targets unhealthy no NLB"
    echo "   4. Pod não está escutando na porta correta"
else
    echo "⚠️  HTTP ${HTTP_CODE}"
fi
echo ""

# 8. Logs recentes da API
echo "8️⃣  Logs Recentes da API (últimas 10 linhas):"
kubectl logs -l app=api -n $NAMESPACE --tail=10 2>&1 | grep -v "^error:"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Comandos Úteis:"
echo ""
echo "Ver logs completos:"
echo "  kubectl logs -l app=api -n $NAMESPACE --tail=100"
echo ""
echo "Recriar serviço (se target type estiver errado):"
echo "  kubectl delete svc api-service -n $NAMESPACE"
echo "  kubectl apply -f k8s/api/service.yaml"
echo ""
echo "Port-forward para teste local:"
echo "  kubectl port-forward -n $NAMESPACE svc/api-service 8080:5180"
echo "  curl http://localhost:8080/health"
echo ""
