#!/bin/bash

NAMESPACE="smart-mechanical-workshop-dev"

echo "🔍 Debugging API deployment in $NAMESPACE"
echo ""

# Get pod name
POD_NAME=$(kubectl get pods -n $NAMESPACE | grep "dev-api-deployment" | awk '{print $1}' | head -1)

if [ -z "$POD_NAME" ]; then
    echo "❌ No API pod found"
    exit 1
fi

echo "📦 Pod: $POD_NAME"
echo ""

echo "📊 Pod Status:"
kubectl get pod $POD_NAME -n $NAMESPACE -o wide

echo ""
echo "📋 Pod Description:"
kubectl describe pod $POD_NAME -n $NAMESPACE

echo ""
echo "📝 Current Logs:"
kubectl logs $POD_NAME -n $NAMESPACE --tail=50

echo ""
echo "📝 Previous Logs (if available):"
kubectl logs $POD_NAME -n $NAMESPACE --previous --tail=50 2>/dev/null || echo "No previous logs available"

echo ""
echo "🔗 Services:"
kubectl get svc -n $NAMESPACE

echo ""
echo "💾 ConfigMaps:"
kubectl get configmap -n $NAMESPACE

echo ""
echo "🔐 Secrets:"
kubectl get secrets -n $NAMESPACE
