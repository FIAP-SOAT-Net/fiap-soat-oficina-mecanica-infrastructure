#!/bin/bash

set -e

ENVIRONMENT=${1:-development}

if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
    echo "❌ Invalid environment. Use: development, staging, or production"
    exit 1
fi

echo "🚀 Deploying Smart Mechanical Workshop to $ENVIRONMENT environment..."

# Apply the specific environment overlay
kubectl apply -k overlays/$ENVIRONMENT/

echo "✅ Deployment to $ENVIRONMENT completed!"

# Get the correct namespace suffix
case $ENVIRONMENT in
    development) NS_SUFFIX="dev" ;;
    staging) NS_SUFFIX="staging" ;;
    production) NS_SUFFIX="prod" ;;
esac

echo "📊 Check status with: kubectl get all -n smart-mechanical-workshop-$NS_SUFFIX"

# Show some useful commands
echo ""
echo "🔧 Useful commands:"
echo "  kubectl get all -n smart-mechanical-workshop-$NS_SUFFIX"
echo "  kubectl logs -l app.kubernetes.io/name=smart-mechanical-workshop-api -n smart-mechanical-workshop-$NS_SUFFIX"
echo "  kubectl get hpa -n smart-mechanical-workshop-$NS_SUFFIX"
