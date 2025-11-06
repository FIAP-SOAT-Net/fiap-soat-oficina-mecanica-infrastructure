#!/bin/bash

# Script para limpeza completa de recursos AWS - Versão Pipeline
# Este script é otimizado para execução em pipelines CI/CD
set -e

REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-smart-mechanical-workshop}"
ENV="${ENVIRONMENT:-production}"
DRY_RUN="${DRY_RUN:-false}"

echo "🧹 Smart Mechanical Workshop - AWS Complete Cleanup (Pipeline Version)"
echo "======================================================================"
echo "Region: $REGION"
echo "Project: $PROJECT_NAME-$ENV"
echo "Dry Run: $DRY_RUN"
echo "Started at: $(date)"
echo ""

# Função para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para verificar se um recurso existe
resource_exists() {
    local check_command="$1"
    eval "$check_command" >/dev/null 2>&1
}

# Função para executar comando com dry-run
execute_or_dry_run() {
    local description="$1"
    local command="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute - $description"
        log "Command: $command"
    else
        log "Executing: $description"
        eval "$command" || {
            log "Warning: Command failed but continuing - $description"
            return 1
        }
    fi
}

log "🔍 Step 1: Analyzing existing AWS resources..."

# 1. Verificar EKS Clusters
log "Checking EKS clusters..."
EKS_CLUSTERS=$(aws eks list-clusters --region $REGION --query 'clusters[]' --output text 2>/dev/null || echo "")
if [[ -n "$EKS_CLUSTERS" ]]; then
    log "Found EKS clusters: $EKS_CLUSTERS"
    echo "::notice title=EKS Clusters Found::$EKS_CLUSTERS"
fi

# 2. Verificar RDS Instances
log "Checking RDS instances..."
RDS_INSTANCES=$(aws rds describe-db-instances --region $REGION --query 'DBInstances[?starts_with(DBInstanceIdentifier, `'$PROJECT_NAME'`)].DBInstanceIdentifier' --output text 2>/dev/null || echo "")
if [[ -n "$RDS_INSTANCES" ]]; then
    log "Found RDS instances: $RDS_INSTANCES"
    echo "::notice title=RDS Instances Found::$RDS_INSTANCES"
fi

# 3. Verificar RDS Parameter Groups
log "Checking RDS parameter groups..."
RDS_PARAM_GROUPS=$(aws rds describe-db-parameter-groups --region $REGION --query 'DBParameterGroups[?starts_with(DBParameterGroupName, `'$PROJECT_NAME'`)].DBParameterGroupName' --output text 2>/dev/null || echo "")
if [[ -n "$RDS_PARAM_GROUPS" ]]; then
    log "Found RDS parameter groups: $RDS_PARAM_GROUPS"
fi

# 4. Verificar RDS Subnet Groups
log "Checking RDS subnet groups..."
RDS_SUBNET_GROUPS=$(aws rds describe-db-subnet-groups --region $REGION --query 'DBSubnetGroups[?starts_with(DBSubnetGroupName, `'$PROJECT_NAME'`)].DBSubnetGroupName' --output text 2>/dev/null || echo "")
if [[ -n "$RDS_SUBNET_GROUPS" ]]; then
    log "Found RDS subnet groups: $RDS_SUBNET_GROUPS"
fi

# 5. Verificar VPCs
log "Checking VPCs..."
VPCS=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Name,Values=$PROJECT_NAME-*" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")
if [[ -n "$VPCS" ]]; then
    log "Found VPCs: $VPCS"
    echo "::notice title=VPCs Found::$VPCS"
fi

# 6. Verificar Load Balancers
log "Checking Load Balancers..."
LOAD_BALANCERS=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?contains(LoadBalancerName, `'$PROJECT_NAME'`)].LoadBalancerArn' --output text 2>/dev/null || echo "")
if [[ -n "$LOAD_BALANCERS" ]]; then
    log "Found Load Balancers: $LOAD_BALANCERS"
    echo "::notice title=Load Balancers Found::$LOAD_BALANCERS"
fi

echo ""
log "📋 Summary of resources found:"
log "- EKS Clusters: ${EKS_CLUSTERS:-'None'}"
log "- RDS Instances: ${RDS_INSTANCES:-'None'}"
log "- RDS Parameter Groups: ${RDS_PARAM_GROUPS:-'None'}"
log "- RDS Subnet Groups: ${RDS_SUBNET_GROUPS:-'None'}"
log "- VPCs: ${VPCS:-'None'}"
log "- Load Balancers: ${LOAD_BALANCERS:-'None'}"
echo ""

# Se não há recursos, sair
if [[ -z "$EKS_CLUSTERS" && -z "$RDS_INSTANCES" && -z "$VPCS" && -z "$LOAD_BALANCERS" ]]; then
    log "✅ No resources found to clean up. Infrastructure is already clean."
    echo "::notice title=Clean Infrastructure::No AWS resources found to clean up"
    exit 0
fi

# GitHub Actions - Criar resumo
if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
    cat >> $GITHUB_STEP_SUMMARY << EOF
## 🧹 AWS Resources Cleanup Summary

### Resources Found:
- **EKS Clusters**: ${EKS_CLUSTERS:-'None'}
- **RDS Instances**: ${RDS_INSTANCES:-'None'}
- **RDS Parameter Groups**: ${RDS_PARAM_GROUPS:-'None'}
- **RDS Subnet Groups**: ${RDS_SUBNET_GROUPS:-'None'}
- **VPCs**: ${VPCS:-'None'}
- **Load Balancers**: ${LOAD_BALANCERS:-'None'}

EOF
fi

log "🗑️ Step 2: Starting cleanup process..."

# 1. Deletar Load Balancers primeiro (dependências dos outros recursos)
if [[ -n "$LOAD_BALANCERS" ]]; then
    for lb_arn in $LOAD_BALANCERS; do
        execute_or_dry_run "Delete Load Balancer: $lb_arn" \
            "aws elbv2 delete-load-balancer --load-balancer-arn '$lb_arn' --region $REGION"

        if [[ "$DRY_RUN" != "true" ]]; then
            log "Waiting 60 seconds for Load Balancer deletion..."
            sleep 60
        fi
    done
fi

# 2. Deletar EKS Node Groups primeiro, depois Clusters
if [[ -n "$EKS_CLUSTERS" ]]; then
    for cluster in $EKS_CLUSTERS; do
        if [[ "$cluster" == *"$PROJECT_NAME"* ]]; then
            log "Processing EKS cluster: $cluster"

            # Deletar Node Groups primeiro
            NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$cluster" --region $REGION --query 'nodegroups[]' --output text 2>/dev/null || echo "")
            if [[ -n "$NODE_GROUPS" ]]; then
                for nodegroup in $NODE_GROUPS; do
                    execute_or_dry_run "Delete EKS node group: $nodegroup" \
                        "aws eks delete-nodegroup --cluster-name '$cluster' --nodegroup-name '$nodegroup' --region $REGION"
                done

                # Aguardar node groups serem deletados
                if [[ "$DRY_RUN" != "true" ]]; then
                    log "Waiting for node groups to be deleted..."
                    for nodegroup in $NODE_GROUPS; do
                        aws eks wait nodegroup-deleted --cluster-name "$cluster" --nodegroup-name "$nodegroup" --region $REGION || true
                    done
                fi
            fi

            # Deletar o cluster
            execute_or_dry_run "Delete EKS cluster: $cluster" \
                "aws eks delete-cluster --name '$cluster' --region $REGION"

            if [[ "$DRY_RUN" != "true" ]]; then
                log "Waiting for EKS cluster deletion..."
                aws eks wait cluster-deleted --name "$cluster" --region $REGION || true
            fi
        fi
    done
fi

# 3. Deletar RDS Instances
if [[ -n "$RDS_INSTANCES" ]]; then
    for instance in $RDS_INSTANCES; do
        execute_or_dry_run "Delete RDS instance: $instance" \
            "aws rds delete-db-instance --db-instance-identifier '$instance' --skip-final-snapshot --region $REGION"

        if [[ "$DRY_RUN" != "true" ]]; then
            log "Waiting for RDS instance deletion..."
            aws rds wait db-instance-deleted --db-instance-identifier "$instance" --region $REGION || true
        fi
    done
fi

# 4. Deletar RDS Parameter Groups
if [[ -n "$RDS_PARAM_GROUPS" ]]; then
    for param_group in $RDS_PARAM_GROUPS; do
        if [[ "$param_group" != "default."* ]]; then
            execute_or_dry_run "Delete RDS parameter group: $param_group" \
                "aws rds delete-db-parameter-group --db-parameter-group-name '$param_group' --region $REGION"
        fi
    done
fi

# 5. Deletar RDS Subnet Groups
if [[ -n "$RDS_SUBNET_GROUPS" ]]; then
    for subnet_group in $RDS_SUBNET_GROUPS; do
        execute_or_dry_run "Delete RDS subnet group: $subnet_group" \
            "aws rds delete-db-subnet-group --db-subnet-group-name '$subnet_group' --region $REGION"
    done
fi

if [[ "$DRY_RUN" != "true" ]]; then
    log "⏳ Step 3: Waiting for all deletions to complete..."
    sleep 60
fi

log "🧹 Step 4: Pre-cleanup - Releasing Elastic IPs..."

# Liberar Elastic IPs ANTES da limpeza das VPCs
EIPS=$(aws ec2 describe-addresses --region $REGION --query 'Addresses[?AssociationId==null].AllocationId' --output text || echo "")
if [[ -n "$EIPS" ]]; then
    for eip in $EIPS; do
        execute_or_dry_run "Release Elastic IP: $eip" \
            "aws ec2 release-address --allocation-id '$eip' --region $REGION"
    done

    if [[ "$DRY_RUN" != "true" ]]; then
        log "Waiting for Elastic IPs to be released..."
        sleep 30
    fi
fi

log "🧹 Step 5: Final cleanup of remaining resources..."

# Cleanup VPC resources
if [[ -n "$VPCS" ]]; then
    for vpc_id in $VPCS; do
        log "Cleaning up VPC resources for: $vpc_id"

        # 1. Abordagem mais agressiva para Elastic IPs
        log "Finding all Elastic IPs for VPC: $vpc_id (aggressive approach)"

        # FORÇA liberação de TODOS os Elastic IPs no account (abordagem agressiva)
        ALL_EIPS=$(aws ec2 describe-addresses --region $REGION --query 'Addresses[].AllocationId' --output text 2>/dev/null || echo "")
        if [[ -n "$ALL_EIPS" ]]; then
            for eip in $ALL_EIPS; do
                execute_or_dry_run "Force release Elastic IP: $eip" \
                    "aws ec2 release-address --allocation-id '$eip' --region $REGION"
            done
        fi

        # Aguardar liberação
        if [[ "$DRY_RUN" != "true" ]]; then
            log "Waiting for all Elastic IPs to be released..."
            sleep 60
        fi        # 2. Abordagem mais agressiva para NAT Gateways
        log "Force deleting ALL NAT Gateways in account (aggressive approach)"
        ALL_NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --region $REGION --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text 2>/dev/null || echo "")
        if [[ -n "$ALL_NAT_GATEWAYS" ]]; then
            for nat_gw in $ALL_NAT_GATEWAYS; do
                execute_or_dry_run "Force delete NAT Gateway: $nat_gw" \
                    "aws ec2 delete-nat-gateway --nat-gateway-id '$nat_gw' --region $REGION"
            done
            if [[ "$DRY_RUN" != "true" ]]; then
                log "Waiting for NAT Gateways deletion..."
                sleep 120  # Tempo estendido para NAT Gateway cleanup
            fi
        fi

        # 3. Verificar e liberar quaisquer Elastic IPs restantes
        REMAINING_EIPS=$(aws ec2 describe-addresses --region $REGION --query 'Addresses[?AssociationId==null].AllocationId' --output text || echo "")
        if [[ -n "$REMAINING_EIPS" ]]; then
            for eip in $REMAINING_EIPS; do
                execute_or_dry_run "Release remaining Elastic IP: $eip" \
                    "aws ec2 release-address --allocation-id '$eip' --region $REGION"
            done
            if [[ "$DRY_RUN" != "true" ]]; then
                log "Waiting for remaining Elastic IPs to be released..."
                sleep 30
            fi
        fi

        # 4. Força terminação de instâncias EC2 na VPC
        log "Force terminating any EC2 instances in VPC: $vpc_id"
        EC2_INSTANCES=$(aws ec2 describe-instances --region $REGION --filters "Name=vpc-id,Values=$vpc_id" "Name=instance-state-name,Values=running,stopped,stopping" --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || echo "")
        if [[ -n "$EC2_INSTANCES" ]]; then
            for instance in $EC2_INSTANCES; do
                execute_or_dry_run "Force terminate EC2 instance: $instance" \
                    "aws ec2 terminate-instances --instance-ids '$instance' --region $REGION"
            done
            if [[ "$DRY_RUN" != "true" ]]; then
                log "Waiting for EC2 instances termination..."
                sleep 60
            fi
        fi

        # Deletar Network Interfaces não anexadas (se houver)
        NETWORK_INTERFACES=$(aws ec2 describe-network-interfaces --region $REGION --filters "Name=vpc-id,Values=$vpc_id" "Name=status,Values=available" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text || echo "")
        if [[ -n "$NETWORK_INTERFACES" ]]; then
            for ni in $NETWORK_INTERFACES; do
                execute_or_dry_run "Delete Network Interface: $ni" \
                    "aws ec2 delete-network-interface --network-interface-id '$ni' --region $REGION"
            done
        fi

        # 5. Verificação final de Elastic IPs antes do Internet Gateway
        FINAL_CHECK_EIPS=$(aws ec2 describe-addresses --region $REGION --filters "Name=domain,Values=vpc" --query 'Addresses[].AllocationId' --output text || echo "")
        if [[ -n "$FINAL_CHECK_EIPS" ]]; then
            log "Found remaining Elastic IPs, attempting final cleanup..."
            for eip in $FINAL_CHECK_EIPS; do
                execute_or_dry_run "Force release Elastic IP: $eip" \
                    "aws ec2 release-address --allocation-id '$eip' --region $REGION"
            done
            if [[ "$DRY_RUN" != "true" ]]; then
                log "Final wait for Elastic IP cleanup..."
                sleep 60
            fi
        fi

        # 6. Deletar Internet Gateways (agora deve funcionar)
        IGW=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[].InternetGatewayId' --output text || echo "")
        if [[ -n "$IGW" ]]; then
            # Tentar desanexar com retry
            retry_count=0
            max_retries=3

            while [[ $retry_count -lt $max_retries ]]; do
                if execute_or_dry_run "Detach Internet Gateway (attempt $((retry_count + 1))): $IGW" \
                    "aws ec2 detach-internet-gateway --internet-gateway-id '$IGW' --vpc-id '$vpc_id' --region $REGION"; then
                    break
                fi

                retry_count=$((retry_count + 1))
                if [[ $retry_count -lt $max_retries ]]; then
                    log "Retrying in 30 seconds..."
                    if [[ "$DRY_RUN" != "true" ]]; then
                        sleep 30
                    fi
                fi
            done

            execute_or_dry_run "Delete Internet Gateway: $IGW" \
                "aws ec2 delete-internet-gateway --internet-gateway-id '$IGW' --region $REGION"
        fi

        # 7. Deletar Security Groups (exceto default)
        SECURITY_GROUPS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text || echo "")
        if [[ -n "$SECURITY_GROUPS" ]]; then
            for sg in $SECURITY_GROUPS; do
                execute_or_dry_run "Delete Security Group: $sg" \
                    "aws ec2 delete-security-group --group-id '$sg' --region $REGION"
            done
        fi

        # 8. Deletar Subnets
        SUBNETS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text || echo "")
        if [[ -n "$SUBNETS" ]]; then
            for subnet in $SUBNETS; do
                execute_or_dry_run "Delete Subnet: $subnet" \
                    "aws ec2 delete-subnet --subnet-id '$subnet' --region $REGION"
            done
        fi

        # 9. Deletar Route Tables (exceto main)
        ROUTE_TABLES=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text || echo "")
        if [[ -n "$ROUTE_TABLES" ]]; then
            for rt in $ROUTE_TABLES; do
                execute_or_dry_run "Delete Route Table: $rt" \
                    "aws ec2 delete-route-table --route-table-id '$rt' --region $REGION"
            done
        fi

        # 10. Finalmente, deletar a VPC
        execute_or_dry_run "Delete VPC: $vpc_id" \
            "aws ec2 delete-vpc --vpc-id '$vpc_id' --region $REGION"
    done
fi

log "🎉 Cleanup process completed!"

if [[ "$DRY_RUN" != "true" ]]; then
    log "🔍 Step 5: Verification - checking remaining resources..."

    # Verificação final
    REMAINING_EKS=$(aws eks list-clusters --region $REGION --query 'clusters[]' --output text 2>/dev/null || echo "")
    REMAINING_RDS=$(aws rds describe-db-instances --region $REGION --query 'DBInstances[?starts_with(DBInstanceIdentifier, `'$PROJECT_NAME'`)].DBInstanceIdentifier' --output text 2>/dev/null || echo "")
    REMAINING_VPCS=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Name,Values=$PROJECT_NAME-*" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")

    log "Remaining EKS clusters: ${REMAINING_EKS:-'None'}"
    log "Remaining RDS instances: ${REMAINING_RDS:-'None'}"
    log "Remaining VPCs with project tags: ${REMAINING_VPCS:-'None'}"

    # GitHub Actions Summary
    if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
        cat >> $GITHUB_STEP_SUMMARY << EOF

### 🔍 Post-Cleanup Verification:
- **Remaining EKS Clusters**: ${REMAINING_EKS:-'✅ None'}
- **Remaining RDS Instances**: ${REMAINING_RDS:-'✅ None'}
- **Remaining VPCs**: ${REMAINING_VPCS:-'✅ None'}

EOF
    fi

    if [[ -n "$REMAINING_EKS" || -n "$REMAINING_RDS" || -n "$REMAINING_VPCS" ]]; then
        log "⚠️ Warning: Some resources may still exist. Manual cleanup may be required."
        echo "::warning title=Incomplete Cleanup::Some resources may still exist"
        exit 1
    fi
fi

log "✅ AWS cleanup completed successfully!"
log "📝 Cleanup completed at: $(date)"

if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
    echo "## ✅ Cleanup Completed Successfully" >> $GITHUB_STEP_SUMMARY
    echo "All AWS resources have been cleaned up at $(date)" >> $GITHUB_STEP_SUMMARY
fi
