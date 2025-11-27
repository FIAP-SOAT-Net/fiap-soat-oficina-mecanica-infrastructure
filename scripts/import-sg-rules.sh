#!/bin/bash

# Script para importar regras de Security Group existentes para o Terraform state
set -e

cd "$(dirname "$0")/../terraform"

SG_ID="sg-0954afae6c4320d7c"
AWS_REGION="us-west-2"

echo "🔍 Importando regras de Security Group para o Terraform..."
echo "Security Group ID: $SG_ID"
echo ""

# Buscar ID da regra porta 5180
echo "1️⃣  Buscando regra para porta 5180..."
# Formato: SECURITYGROUPID_TYPE_PROTOCOL_FROMPORT_TOPORT_SOURCE
IMPORT_ID_5180="${SG_ID}_ingress_tcp_5180_5180_0.0.0.0/0"
echo "   Import ID: $IMPORT_ID_5180"
echo "   Importando..."
terraform import aws_security_group_rule.eks_api_ingress "$IMPORT_ID_5180" 2>&1 | grep -v "Acquiring state lock" || echo "   ✅ Importada"
echo ""

# Buscar ID da regra porta 8025
echo "2️⃣  Buscando regra para porta 8025..."
IMPORT_ID_8025="${SG_ID}_ingress_tcp_8025_8025_0.0.0.0/0"
echo "   Import ID: $IMPORT_ID_8025"
echo "   Importando..."
terraform import aws_security_group_rule.eks_mailhog_ingress "$IMPORT_ID_8025" 2>&1 | grep -v "Acquiring state lock" || echo "   ✅ Importada"
echo ""

# Buscar ID da regra self-referencing
echo "3️⃣  Buscando regra self-referencing..."
IMPORT_ID_SELF="${SG_ID}_ingress_all_0_0_${SG_ID}"
echo "   Import ID: $IMPORT_ID_SELF"
echo "   Importando..."
terraform import aws_security_group_rule.eks_internal_ingress "$IMPORT_ID_SELF" 2>&1 | grep -v "Acquiring state lock" || echo "   ✅ Importada"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Importação concluída!"
echo ""
echo "Verificando state..."
terraform state list | grep security_group_rule
echo ""
echo "🎯 Próximo passo: terraform plan"
