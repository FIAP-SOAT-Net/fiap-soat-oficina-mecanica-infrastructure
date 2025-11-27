#!/bin/bash

# Script para configurar a role IAM do GitHub Actions com OIDC
# Este script deve ser executado ANTES de configurar os workflows do GitHub Actions

set -e

# Configurações
ROLE_NAME="GitHubActionsEKSRole"
AWS_REGION="us-west-2"
GITHUB_ORG="FIAP-SOAT-Net"
GITHUB_REPO="fiap-soat-oficina-mecanica-infrastructure"
TERRAFORM_STATE_BUCKET="smart-workshop-infrastructure-terraform-state"
TERRAFORM_LOCKS_TABLE="smart-workshop-terraform-locks"

echo "🚀 Configurando IAM Role para GitHub Actions..."
echo ""

# Verificar se AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não está instalado. Por favor, instale: https://aws.amazon.com/cli/"
    exit 1
fi

# Verificar se está configurado
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI não está configurado. Execute: aws configure"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account ID: ${AWS_ACCOUNT_ID}"
echo ""

# 1. Criar OIDC Provider (se não existir)
echo "🔐 Configurando OIDC Provider do GitHub..."
OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_PROVIDER_ARN}" 2>&1 | grep -q 'NoSuchEntity'; then
    echo "   Criando OIDC Provider..."
    
    aws iam create-open-id-connect-provider \
        --url "https://token.actions.githubusercontent.com" \
        --client-id-list "sts.amazonaws.com" \
        --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
        --tags Key=Name,Value=GitHubActionsOIDC
    
    echo "   ✅ OIDC Provider criado"
else
    echo "   ✅ OIDC Provider já existe"
fi
echo ""

# 2. Criar Trust Policy
echo "📝 Criando Trust Policy..."
cat > /tmp/github-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
echo "   ✅ Trust Policy criada"
echo ""

# 3. Criar IAM Role
echo "👤 Criando IAM Role: ${ROLE_NAME}..."
if aws iam get-role --role-name "${ROLE_NAME}" 2>&1 | grep -q 'NoSuchEntity'; then
    aws iam create-role \
        --role-name "${ROLE_NAME}" \
        --assume-role-policy-document file:///tmp/github-trust-policy.json \
        --description "Role for GitHub Actions to manage EKS infrastructure" \
        --tags Key=Name,Value="${ROLE_NAME}" Key=ManagedBy,Value=Script
    
    echo "   ✅ Role criada"
else
    echo "   ⚠️  Role já existe, atualizando trust policy..."
    aws iam update-assume-role-policy \
        --role-name "${ROLE_NAME}" \
        --policy-document file:///tmp/github-trust-policy.json
    echo "   ✅ Trust policy atualizada"
fi
echo ""

# 4. Criar e anexar políticas necessárias
echo "📋 Configurando permissões..."

# Política 1: Acesso ao Terraform State (S3 + DynamoDB)
echo "   1️⃣  Terraform State Access..."
cat > /tmp/terraform-state-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": "arn:aws:s3:::${TERRAFORM_STATE_BUCKET}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${TERRAFORM_STATE_BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${TERRAFORM_LOCKS_TABLE}"
    }
  ]
}
EOF

POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/TerraformStateAccessPolicy"
if aws iam get-policy --policy-arn "${POLICY_ARN}" 2>&1 | grep -q 'NoSuchEntity'; then
    aws iam create-policy \
        --policy-name "TerraformStateAccessPolicy" \
        --policy-document file:///tmp/terraform-state-policy.json \
        --description "Allows access to Terraform state in S3 and DynamoDB"
    echo "      ✅ Policy criada"
else
    echo "      ✅ Policy já existe"
fi

aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "${POLICY_ARN}" 2>/dev/null || echo "      ✅ Policy já anexada"

# Política 2: EKS Full Access
echo "   2️⃣  EKS Full Access..."
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/EKSFullAccessPolicy"
if aws iam get-policy --policy-arn "${POLICY_ARN}" 2>&1 | grep -q 'NoSuchEntity'; then
    cat > /tmp/eks-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceLinkedRole"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": [
            "eks.amazonaws.com",
            "eks-nodegroup.amazonaws.com",
            "eks-fargate.amazonaws.com"
          ]
        }
      }
    }
  ]
}
EOF
    aws iam create-policy \
        --policy-name "EKSFullAccessPolicy" \
        --policy-document file:///tmp/eks-policy.json \
        --description "Full access to EKS resources"
    echo "      ✅ Policy criada"
else
    echo "      ✅ Policy já existe"
fi

aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "${POLICY_ARN}" 2>/dev/null || echo "      ✅ Policy já anexada"

# Política 3: EC2, VPC, IAM (para Terraform)
echo "   3️⃣  EC2, VPC e IAM Access..."
aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess" 2>/dev/null || echo "      ✅ Policy já anexada"

aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::aws:policy/IAMFullAccess" 2>/dev/null || echo "      ✅ Policy já anexada"

aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonVPCFullAccess" 2>/dev/null || echo "      ✅ Policy já anexada"

# Política 4: Elastic Load Balancing
echo "   4️⃣  Elastic Load Balancing..."
aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess" 2>/dev/null || echo "      ✅ Policy já anexada"

echo ""
echo "✅ Configuração concluída com sucesso!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Informações para configurar no GitHub:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Role ARN (adicione como secret AWS_ROLE_ARN):"
echo "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo ""
echo "Região AWS (adicione como secret AWS_REGION):"
echo "${AWS_REGION}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 Próximos passos:"
echo "  1. Adicionar secrets no GitHub:"
echo "     - AWS_ROLE_ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo "     - AWS_REGION: ${AWS_REGION}"
echo "     - DB_PASSWORD: (senha do RDS)"
echo "     - RDS_ENDPOINT: (endpoint do RDS)"
echo "  2. Executar workflow: 🚀 Deploy Infrastructure"
echo ""

# Cleanup
rm -f /tmp/github-trust-policy.json /tmp/terraform-state-policy.json /tmp/eks-policy.json
