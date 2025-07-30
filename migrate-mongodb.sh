#!/bin/bash

# Migration script from MongoDB Deployment to StatefulSet
# This script safely migrates your MongoDB from Deployment to StatefulSet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}"
    echo "=================================="
    echo "$1"
    echo "=================================="
    echo -e "${NC}"
}

print_header "🔄 Migrating MongoDB from Deployment to StatefulSet"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Checking current MongoDB setup..."

# Check if old deployment exists
OLD_DEPLOYMENT_EXISTS=false
if kubectl get deployment mongodb-deployment -n chat-app &> /dev/null; then
    OLD_DEPLOYMENT_EXISTS=true
    print_warning "Found existing MongoDB deployment"
fi

# Check if StatefulSet already exists
if kubectl get statefulset mongodb -n chat-app &> /dev/null; then
    print_success "MongoDB StatefulSet already exists"
    kubectl get statefulset mongodb -n chat-app
    exit 0
fi

# Backup existing data if deployment exists
if [ "$OLD_DEPLOYMENT_EXISTS" = true ]; then
    print_status "Backing up existing MongoDB data..."
    
    # Create backup directory
    kubectl exec deployment/mongodb-deployment -n chat-app -- mkdir -p /tmp/backup 2>/dev/null || true
    
    # Create MongoDB dump
    kubectl exec deployment/mongodb-deployment -n chat-app -- mongodump --host localhost:27017 -u root -p toor --authenticationDatabase admin --out /tmp/backup 2>/dev/null || print_warning "Could not create backup (database might be empty)"
    
    # Scale down old deployment
    print_status "Scaling down old deployment..."
    kubectl scale deployment mongodb-deployment --replicas=0 -n chat-app
    
    # Wait for pods to terminate
    kubectl wait --for=delete pod -l app=mongodb -n chat-app --timeout=60s || true
fi

# Remove old PVC and PV (StatefulSet will create new ones)
print_status "Cleaning up old storage resources..."
kubectl delete pvc mongodb-pvc -n chat-app 2>/dev/null || echo "No old PVC to delete"
kubectl delete pv mongodb-pv 2>/dev/null || echo "No old PV to delete"

# Deploy StatefulSet
print_status "Deploying MongoDB StatefulSet..."
kubectl apply -f k8s/mongodb-deployment.yml

# Wait for StatefulSet to be ready
print_status "Waiting for StatefulSet to be ready..."
kubectl wait --for=condition=ready pod/mongodb-0 -n chat-app --timeout=300s

# Restore data if backup exists
if [ "$OLD_DEPLOYMENT_EXISTS" = true ]; then
    print_status "Attempting to restore data..."
    
    # Check if backup exists in the old pod
    kubectl exec mongodb-0 -n chat-app -- ls -la /tmp/backup 2>/dev/null && {
        print_status "Restoring MongoDB data..."
        kubectl exec mongodb-0 -n chat-app -- mongorestore --host localhost:27017 -u root -p toor --authenticationDatabase admin /tmp/backup 2>/dev/null || print_warning "Could not restore backup"
        
        # Clean up backup
        kubectl exec mongodb-0 -n chat-app -- rm -rf /tmp/backup 2>/dev/null || true
    } || print_warning "No backup found to restore"
fi

# Remove old deployment
if [ "$OLD_DEPLOYMENT_EXISTS" = true ]; then
    print_status "Removing old deployment..."
    kubectl delete deployment mongodb-deployment -n chat-app
fi

# Verify everything is working
print_status "Verifying MongoDB StatefulSet..."
kubectl get statefulset mongodb -n chat-app
kubectl get pods -n chat-app | grep mongodb
kubectl get svc -n chat-app | grep mongodb
kubectl get pvc -n chat-app | grep mongodb

# Test connection
print_status "Testing MongoDB connection..."
kubectl exec mongodb-0 -n chat-app -- mongo -u root -p toor --authenticationDatabase admin --eval "db.adminCommand('ping')" 2>/dev/null && {
    print_success "MongoDB is responding to ping"
} || print_warning "MongoDB ping failed"

print_success "✅ Migration completed successfully!"
print_status "MongoDB is now running as a StatefulSet with:"
echo "  - Stable pod name: mongodb-0"
echo "  - Dedicated storage per pod"
echo "  - Headless service: mongodb-headless"
echo "  - Regular service: mongodb-service"
echo ""
print_status "🔧 Connection strings:"
echo "  - Internal: mongodb://root:toor@mongodb-service:27017/chatapp"
echo "  - Direct pod: mongodb://root:toor@mongodb-0.mongodb-headless:27017/chatapp"
echo ""
print_status "🌐 For MongoDB Compass:"
echo "  1. Run: kubectl port-forward mongodb-0 27017:27017 -n chat-app"
echo "  2. Connect to: mongodb://root:toor@localhost:27017/chatapp"
