#!/bin/bash

# Script para criar o backend S3 e DynamoDB para o Terraform
# Este script deve ser executado ANTES do terraform init

set -e

# Configurações
BUCKET_NAME="smart-workshop-infrastructure-terraform-state"
DYNAMODB_TABLE="smart-workshop-terraform-locks"
AWS_REGION="us-west-2"

echo "🚀 Configurando backend do Terraform..."
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

echo "✅ AWS CLI configurado"
echo ""

# Criar bucket S3
echo "📦 Verificando bucket S3: ${BUCKET_NAME}..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "   Criando bucket S3..."
    
    # Criar bucket (sem LocationConstraint para us-east-1, com LocationConstraint para outras regiões)
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    
    # Habilitar versionamento
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled
    
    # Habilitar encriptação
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    # Bloquear acesso público
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    echo "   ✅ Bucket S3 criado e configurado"
else
    echo "   ✅ Bucket S3 já existe"
fi
echo ""

# Criar tabela DynamoDB
echo "🔐 Verificando tabela DynamoDB: ${DYNAMODB_TABLE}..."
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" 2>&1 | grep -q 'ResourceNotFoundException'; then
    echo "   Criando tabela DynamoDB..."
    
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}"
    
    echo "   Aguardando tabela ficar ativa..."
    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${AWS_REGION}"
    
    echo "   ✅ Tabela DynamoDB criada"
else
    echo "   ✅ Tabela DynamoDB já existe"
fi
echo ""

echo "✅ Backend do Terraform configurado com sucesso!"
echo ""
echo "Recursos criados:"
echo "  • Bucket S3: ${BUCKET_NAME}"
echo "  • Tabela DynamoDB: ${DYNAMODB_TABLE}"
echo "  • Região: ${AWS_REGION}"
echo ""
echo "🎯 Próximos passos:"
echo "  1. cd terraform"
echo "  2. terraform init"
echo "  3. terraform plan"
echo ""
