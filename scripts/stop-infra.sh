#!/bin/bash

# Script to stop the EKS infrastructure
# Usage: ./stop-infra.sh

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-smart-workshop-dev-cluster}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="${NAMESPACE:-smart-workshop}"
NODE_GROUP_NAME="${NODE_GROUP_NAME:-smart-workshop-dev-node-group}"

echo "================================================"
echo "🛑 Stopping Smart Workshop Infrastructure"
echo "================================================"
echo ""
echo "Configuration:"
echo "  - Cluster: $CLUSTER_NAME"
echo "  - Region: $REGION"
echo "  - Namespace: $NAMESPACE"
echo "  - Node Group: $NODE_GROUP_NAME"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI is not installed"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed"
    exit 1
fi

# Confirmation prompt
read -p "⚠️  Are you sure you want to stop the infrastructure? This will scale down all deployments. (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Aborted"
    exit 0
fi

# Configure kubectl
echo ""
echo "📋 Configuring kubectl..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Scale deployments to 0
echo ""
echo "📉 Scaling API deployment to 0 replicas..."
kubectl scale deployment api-deployment -n "$NAMESPACE" --replicas=0

echo ""
echo "📉 Scaling MailHog deployment to 0 replicas..."
kubectl scale deployment mailhog-deployment -n "$NAMESPACE" --replicas=0

# Wait for pods to terminate
echo ""
echo "⏳ Waiting for pods to terminate..."
kubectl wait --for=delete pod --all -n "$NAMESPACE" --timeout=300s 2>/dev/null || true

# Show current status
echo ""
echo "Current Pods:"
kubectl get pods -n "$NAMESPACE"

# Scale node group to minimum
echo ""
echo "📉 Keeping node group at 1 node (FREE TIER minimum)..."
echo "⚠️  Note: Free Tier allows 750h/mês (1 t3.small 24/7)"
# No node scaling needed - keep 1 node for Free Tier

# Show current status
echo ""
echo "================================================"
echo "✅ Infrastructure Stopped Successfully!"
echo "================================================"
echo ""
echo "Current Status:"
echo ""
echo "Nodes:"
kubectl get nodes
echo ""
echo "Pods:"
kubectl get pods -n "$NAMESPACE"
echo ""
echo "Deployments:"
kubectl get deployments -n "$NAMESPACE"
echo ""

# Calculate savings
echo "================================================"
echo "💰 Cost Savings"
echo "================================================"
echo ""
echo "With infrastructure stopped:"
echo "  - API Pods: 0 replicas (savings: ~\$0.10/hour)"
echo "  - MailHog: 0 replicas (savings: ~\$0.02/hour)"
echo "  - Nodes: 1 node instead of 2 (savings: ~\$0.04/hour)"
echo ""
echo "Estimated savings: ~\$3-4 per 24 hours when stopped"
echo ""
echo "💡 Tip: Run './start-infra.sh' to start the infrastructure again"
echo ""
