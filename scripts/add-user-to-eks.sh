#!/bin/bash

# Script para adicionar seu usuário IAM ao ConfigMap do EKS
# Usage: ./scripts/add-user-to-eks.sh

set -e

echo "======================================"
echo "  🔐 Adicionar Usuário ao EKS"
echo "======================================"
echo ""

# Obter usuário IAM atual
CURRENT_USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text)
CURRENT_USERNAME=$(aws sts get-caller-identity --query 'UserId' --output text | cut -d':' -f2)

echo "👤 Usuário atual: $CURRENT_USER_ARN"
echo ""

# Criar ConfigMap patch
cat > /tmp/aws-auth-patch.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::243100982781:role/smart-workshop-dev-fargate-pod-execution-role
      username: system:node:{{SessionName}}
      groups:
      - system:bootstrappers
      - system:nodes
      - system:node-proxier
    - rolearn: arn:aws:iam::243100982781:role/GitHubActionsEKSRole
      username: github-actions
      groups:
      - system:masters
  mapUsers: |
    - userarn: ${CURRENT_USER_ARN}
      username: ${CURRENT_USERNAME}
      groups:
      - system:masters
EOF

echo "📝 ConfigMap criado em /tmp/aws-auth-patch.yaml"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   Este comando precisa ser executado POR UM USUÁRIO QUE JÁ TENHA ACESSO ao cluster."
echo "   Normalmente, isso é feito pela role que criou o cluster (GitHubActionsEKSRole)."
echo ""
echo "🔧 Para aplicar manualmente via AWS Console ou CloudShell:"
echo ""
echo "1. Acesse AWS CloudShell (https://console.aws.amazon.com/cloudshell)"
echo "2. Configure kubectl:"
echo "   aws eks update-kubeconfig --region us-west-2 --name smart-workshop-dev-cluster"
echo ""
echo "3. Aplique o ConfigMap:"
echo "   kubectl apply -f - << 'EOF'"
cat /tmp/aws-auth-patch.yaml
echo "EOF"
echo ""
echo "4. Verifique:"
echo "   kubectl get configmap aws-auth -n kube-system -o yaml"
echo ""
echo "======================================"
echo ""
