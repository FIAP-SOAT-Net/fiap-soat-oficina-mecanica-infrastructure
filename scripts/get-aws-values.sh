#!/bin/bash

# Script para obter valores necessários para GitHub Secrets
# Usage: ./scripts/get-aws-values.sh

set -e

echo "======================================"
echo "  Obter Valores para GitHub Secrets"
echo "======================================"
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# VPC ID
echo -e "${YELLOW}🔍 Procurando VPC...${NC}"
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=smart-workshop-*" \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || echo "")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
  echo "⚠️  VPC não encontrada. Tentando listar todas as VPCs:"
  aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table
  echo ""
  read -p "Digite o VPC ID manualmente: " VPC_ID
fi

echo -e "${GREEN}✅ VPC_ID: $VPC_ID${NC}"
echo ""

# Subnet IDs
echo -e "${YELLOW}🔍 Procurando Subnets em AZs diferentes...${NC}"
SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,Tags[?Key==`Name`].Value|[0]]' \
  --output table)

echo "$SUBNETS"
echo ""

# Pegar 2 subnets em AZs diferentes
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[0:2].SubnetId' \
  --output json | jq -c .)

echo -e "${YELLOW}⚠️  IMPORTANTE: Verifique se as subnets estão em AZs DIFERENTES!${NC}"
echo -e "${YELLOW}   Se não estiverem, ajuste manualmente o SUBNET_IDS.${NC}"
echo ""

echo -e "${GREEN}✅ SUBNET_IDS: $SUBNET_IDS${NC}"
echo ""

# RDS Endpoint
echo -e "${YELLOW}🔍 Procurando RDS instance...${NC}"
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `smart-workshop`) || contains(DBInstanceIdentifier, `workshop`)].Endpoint.Address' \
  --output text 2>/dev/null | head -1 || echo "")

if [ -z "$RDS_ENDPOINT" ] || [ "$RDS_ENDPOINT" == "None" ]; then
  echo "⚠️  RDS não encontrado. Listando todos os DB instances:"
  aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Endpoint.Address]' --output table
  echo ""
  read -p "Digite o RDS Endpoint manualmente: " RDS_ENDPOINT
fi

echo -e "${GREEN}✅ RDS_ENDPOINT: $RDS_ENDPOINT${NC}"
echo ""

# JWT Secret Key
echo -e "${YELLOW}🔐 Gerando JWT Secret Key...${NC}"
JWT_SECRET_KEY=$(openssl rand -base64 32)
echo -e "${GREEN}✅ JWT_SECRET_KEY: $JWT_SECRET_KEY${NC}"
echo ""

# IAM Role ARN
echo -e "${YELLOW}🔍 Obtendo IAM Role ARN...${NC}"
ROLE_ARN=$(aws iam get-role --role-name GitHubActionsEKSRole --query 'Role.Arn' --output text 2>/dev/null || echo "")
if [ -z "$ROLE_ARN" ]; then
  echo "⚠️  Role GitHubActionsEKSRole não encontrada. Você precisa criá-la primeiro!"
  ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/GitHubActionsEKSRole"
fi
echo -e "${GREEN}✅ AWS_ROLE_ARN: $ROLE_ARN${NC}"
echo ""

# Resumo
echo "======================================"
echo "  📋 RESUMO - GitHub Secrets"
echo "======================================"
echo ""
echo "Copie e cole estes valores no GitHub:"
echo "Settings → Secrets and variables → Actions → New repository secret"
echo ""
echo "---"
echo "Secret: AWS_REGION"
echo "Value:  us-west-2"
echo ""
echo "---"
echo "Secret: AWS_ROLE_ARN"
echo "Value:  $ROLE_ARN"
echo ""
echo "---"
echo "Secret: TF_STATE_BUCKET"
echo "Value:  smart-workshop-infrastructure-terraform-state"
echo ""
echo "---"
echo "Secret: TF_STATE_KEY"
echo "Value:  dev/terraform.tfstate"
echo ""
echo "---"
echo "Secret: TF_STATE_REGION"
echo "Value:  us-west-2"
echo ""
echo "---"
echo "Secret: VPC_ID"
echo "Value:  $VPC_ID"
echo ""
echo "---"
echo "Secret: SUBNET_IDS"
echo "Value:  $SUBNET_IDS"
echo ""
echo "---"
echo "Secret: RDS_ENDPOINT"
echo "Value:  $RDS_ENDPOINT"
echo ""
echo "---"
echo "Secret: DB_PASSWORD"
echo "Value:  <USE_A_SENHA_DO_SEU_RDS>"
echo ""
echo "---"
echo "Secret: JWT_SECRET_KEY"
echo "Value:  $JWT_SECRET_KEY"
echo ""
echo "======================================"
echo ""

# Salvar em arquivo (opcional)
cat > /tmp/github-secrets.txt << EOF
AWS_REGION=us-west-2
AWS_ROLE_ARN=$ROLE_ARN
TF_STATE_BUCKET=smart-workshop-infrastructure-terraform-state
TF_STATE_KEY=dev/terraform.tfstate
TF_STATE_REGION=us-west-2
VPC_ID=$VPC_ID
SUBNET_IDS=$SUBNET_IDS
RDS_ENDPOINT=$RDS_ENDPOINT
DB_PASSWORD=<USE_A_SENHA_DO_SEU_RDS>
JWT_SECRET_KEY=$JWT_SECRET_KEY
EOF

echo "✅ Valores salvos em: /tmp/github-secrets.txt"
echo ""
echo "⚠️  IMPORTANTE: Não compartilhe este arquivo! Ele contém informações sensíveis."
echo ""
