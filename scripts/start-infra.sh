#!/bin/bash

# Script to start the EKS infrastructure
# Usage: ./start-infra.sh

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-smart-workshop-dev-cluster}"
REGION="${AWS_REGION:-us-west-2}"
NAMESPACE="${NAMESPACE:-smart-workshop}"
NODE_GROUP_NAME="${NODE_GROUP_NAME:-smart-workshop-dev-node-group}"

echo "================================================"
echo "🚀 Starting Smart Workshop Infrastructure"
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

# Configure kubectl
echo "📋 Configuring kubectl..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Scale node group
echo ""
echo "📈 Scaling node group to 1 node (FREE TIER)..."
aws eks update-nodegroup-config \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODE_GROUP_NAME" \
    --scaling-config minSize=1,maxSize=2,desiredSize=1 \
    --region "$REGION"

echo "⏳ Waiting for nodes to be ready (this may take 2-3 minutes)..."
sleep 60

# Check nodes
echo ""
echo "🖥️  Current nodes:"
kubectl get nodes

# Scale API deployment
echo ""
echo "📈 Scaling API deployment to 1 replica (FREE TIER)..."
kubectl scale deployment api-deployment -n "$NAMESPACE" --replicas=1

# Scale MailHog deployment
echo ""
echo "📧 Scaling MailHog deployment to 1 replica..."
kubectl scale deployment mailhog-deployment -n "$NAMESPACE" --replicas=1

# Wait for deployments
echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/api-deployment -n "$NAMESPACE" || true
kubectl wait --for=condition=available --timeout=300s deployment/mailhog-deployment -n "$NAMESPACE" || true

# Show current status
echo ""
echo "================================================"
echo "✅ Infrastructure Started Successfully!"
echo "================================================"
echo ""
echo "Current Status:"
echo ""
echo "Pods:"
kubectl get pods -n "$NAMESPACE"
echo ""
echo "Services:"
kubectl get svc -n "$NAMESPACE"
echo ""
echo "Deployments:"
kubectl get deployments -n "$NAMESPACE"
echo ""

# Get external endpoints
echo "================================================"
echo "📍 External Endpoints"
echo "================================================"
echo ""

API_ENDPOINT=$(kubectl get svc api-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
MAILHOG_ENDPOINT=$(kubectl get svc mailhog-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

if [ "$API_ENDPOINT" != "pending" ]; then
    echo "🌐 API: http://$API_ENDPOINT:5180"
    echo "📄 Swagger: http://$API_ENDPOINT:5180/swagger"
    echo "❤️  Health: http://$API_ENDPOINT:5180/health"
else
    echo "⏳ API endpoint is still being provisioned..."
fi

echo ""

if [ "$MAILHOG_ENDPOINT" != "pending" ]; then
    echo "📧 MailHog UI: http://$MAILHOG_ENDPOINT:8025"
else
    echo "⏳ MailHog endpoint is still being provisioned..."
fi

echo ""
echo "💡 Tip: Run 'kubectl get svc -n $NAMESPACE' to check endpoints status"
echo ""
