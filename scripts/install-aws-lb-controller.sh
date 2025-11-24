#!/bin/bash

# Script para instalar o AWS Load Balancer Controller no cluster EKS
# Este controller é necessário para LoadBalancers funcionarem corretamente com Fargate
# Usage: ./scripts/install-aws-lb-controller.sh

set -e

echo "======================================"
echo "  📦 Instalar AWS Load Balancer Controller"
echo "======================================"
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="smart-workshop-dev-cluster"
REGION="us-west-2"

echo -e "${BLUE}1️⃣  Obtendo IAM Role ARN...${NC}"
ROLE_ARN=$(aws cloudformation describe-stacks \
  --region $REGION \
  --query "Stacks[?StackName=='eks-aws-load-balancer-controller'].Outputs[?OutputKey=='ServiceAccountRoleArn'].OutputValue" \
  --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
  echo -e "${YELLOW}   Obtendo do Terraform outputs...${NC}"
  cd terraform
  ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn 2>/dev/null || echo "")
  cd ..
fi

if [ -z "$ROLE_ARN" ]; then
  echo -e "${YELLOW}   ⚠️  Role não encontrada via outputs, construindo ARN...${NC}"
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/smart-workshop-dev-aws-lb-controller"
fi

echo -e "${GREEN}   Role ARN: $ROLE_ARN${NC}"
echo ""

echo -e "${BLUE}2️⃣  Criando ServiceAccount...${NC}"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF

echo ""
echo -e "${BLUE}3️⃣  Instalando Helm...${NC}"
if ! command -v helm &> /dev/null; then
  echo -e "${YELLOW}   Helm não encontrado, instalando...${NC}"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo -e "${GREEN}   ✅ Helm já instalado${NC}"
fi

echo ""
echo -e "${BLUE}4️⃣  Adicionando repositório Helm da AWS...${NC}"
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo ""
echo -e "${BLUE}5️⃣  Instalando AWS Load Balancer Controller...${NC}"
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text)

echo ""
echo -e "${BLUE}6️⃣  Aguardando deployment...${NC}"
kubectl rollout status deployment aws-load-balancer-controller -n kube-system --timeout=120s

echo ""
echo -e "${GREEN}✅ AWS Load Balancer Controller instalado com sucesso!${NC}"
echo ""
echo "======================================"
echo -e "  ${BLUE}📋 Verificação${NC}"
echo "======================================"
echo ""
kubectl get deployment -n kube-system aws-load-balancer-controller
echo ""
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
echo ""
echo "======================================"
echo -e "  ${GREEN}✅ Próximos passos${NC}"
echo "======================================"
echo ""
echo "1. Recrie o serviço da API para usar o novo controller:"
echo "   kubectl delete svc api-service -n smart-workshop"
echo "   kubectl apply -f k8s/api/service.yaml"
echo ""
echo "2. Aguarde 2-3 minutos e obtenha a nova URL:"
echo "   ./scripts/test-kubectl-access.sh"
echo ""
