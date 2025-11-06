#!/bin/bash

ENVIRONMENT=${1:-development}

case $ENVIRONMENT in
    development) NS_SUFFIX="dev" ;;
    staging) NS_SUFFIX="staging" ;;
    production) NS_SUFFIX="prod" ;;
esac

NAMESPACE="smart-mechanical-workshop-$NS_SUFFIX"

echo "🌐 Service Status for $ENVIRONMENT environment"
echo "=============================================="

# Get all services
kubectl get svc -n $NAMESPACE

echo ""
echo "🔗 External Access URLs:"
echo "========================"

# API Service
API_INFO=$(kubectl get svc ${NS_SUFFIX}-api-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}' 2>/dev/null)
if [ ! -z "$API_INFO" ] && [ "$API_INFO" != ":" ]; then
    echo "🔗 API: http://$API_INFO"
    echo "❤️  Health: http://$API_INFO/health"
else
    echo "🔗 API: External IP pending..."
fi

# MailHog for development and staging
if [ "$ENVIRONMENT" == "development" ] || [ "$ENVIRONMENT" == "staging" ]; then
    MAILHOG_INFO=$(kubectl get svc ${NS_SUFFIX}-mailhog-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[1].port}' 2>/dev/null)
    if [ ! -z "$MAILHOG_INFO" ] && [ "$MAILHOG_INFO" != ":" ]; then
        echo "📧 MailHog: http://$MAILHOG_INFO"
    else
        echo "📧 MailHog: External IP pending..."
    fi
fi

# MySQL for development and staging
if [ "$ENVIRONMENT" == "development" ] || [ "$ENVIRONMENT" == "staging" ]; then
    MYSQL_INFO=$(kubectl get svc ${NS_SUFFIX}-mysql-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}' 2>/dev/null)
    if [ ! -z "$MYSQL_INFO" ] && [ "$MYSQL_INFO" != ":" ]; then
        echo "🗄️  MySQL: $MYSQL_INFO"
        echo "   Connect with: mysql -h $(echo $MYSQL_INFO | cut -d: -f1) -P $(echo $MYSQL_INFO | cut -d: -f2) -u workshopuser_${ENVIRONMENT:0:3} -p"
    else
        echo "🗄️  MySQL: External IP pending..."
    fi
fi

# Production notes
if [ "$ENVIRONMENT" == "production" ]; then
    echo "🔒 MailHog and MySQL are internal-only in production"
fi

echo ""
echo "📊 Pod Status:"
kubectl get pods -n $NAMESPACE
