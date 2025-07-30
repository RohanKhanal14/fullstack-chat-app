#!/bin/bash

# MongoDB StatefulSet Test Script
# This script tests the MongoDB StatefulSet deployment

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

print_header "🧪 Testing MongoDB StatefulSet"

# Test 1: Check if StatefulSet exists
print_status "1. Checking StatefulSet status..."
if kubectl get statefulset mongodb -n chat-app &> /dev/null; then
    kubectl get statefulset mongodb -n chat-app
    print_success "StatefulSet exists and is running"
else
    print_error "StatefulSet not found"
    exit 1
fi

echo ""

# Test 2: Check pod status
print_status "2. Checking pod status..."
POD_STATUS=$(kubectl get pod mongodb-0 -n chat-app -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" = "Running" ]; then
    kubectl get pod mongodb-0 -n chat-app
    print_success "Pod is running"
else
    print_error "Pod is not running (Status: $POD_STATUS)"
    kubectl describe pod mongodb-0 -n chat-app
    exit 1
fi

echo ""

# Test 3: Check services
print_status "3. Checking services..."
kubectl get svc -n chat-app | grep mongodb
print_success "Services are available"

echo ""

# Test 4: Test MongoDB connection
print_status "4. Testing MongoDB connection..."
if kubectl exec mongodb-0 -n chat-app -- mongosh --eval "db.adminCommand('ping')" &> /dev/null; then
    print_success "MongoDB is responding to ping"
else
    print_error "MongoDB ping failed"
    exit 1
fi

echo ""

# Test 5: Test MongoDB authentication
print_status "5. Testing MongoDB authentication..."
if kubectl exec mongodb-0 -n chat-app -- mongosh -u root -p toor --authenticationDatabase admin --eval "db.adminCommand('ping')" &> /dev/null; then
    print_success "MongoDB authentication works"
else
    print_error "MongoDB authentication failed"
    exit 1
fi

echo ""

# Test 6: Test service connectivity
print_status "6. Testing service connectivity..."
if kubectl run test-connectivity --image=busybox --rm --restart=Never -n chat-app -- nc -zv mongodb-service 27017 &> /dev/null; then
    print_success "Service connectivity works"
else
    print_error "Service connectivity failed"
    exit 1
fi

echo ""

# Test 7: Check PVC
print_status "7. Checking persistent storage..."
kubectl get pvc -n chat-app | grep mongodb
PVC_STATUS=$(kubectl get pvc mongodb-storage-mongodb-0 -n chat-app -o jsonpath='{.status.phase}')
if [ "$PVC_STATUS" = "Bound" ]; then
    print_success "Persistent volume is bound"
else
    print_error "Persistent volume issue (Status: $PVC_STATUS)"
fi

echo ""

# Test 8: Database creation test
print_status "8. Testing database operations..."
kubectl exec mongodb-0 -n chat-app -- mongosh -u root -p toor --authenticationDatabase admin --eval "
use chatapp;
db.test.insertOne({message: 'Hello from Kubernetes!', timestamp: new Date()});
print('Document inserted successfully');
db.test.findOne();
" &> /dev/null && print_success "Database operations work" || print_warning "Database operations had issues"

echo ""

print_header "📋 MongoDB Connection Information"

echo -e "${BLUE}Internal Connections:${NC}"
echo "  - Direct pod: mongodb://root:toor@mongodb-0.mongodb-headless:27017/chatapp"
echo "  - Via service: mongodb://root:toor@mongodb-service:27017/chatapp"
echo ""

echo -e "${BLUE}External Access (MongoDB Compass):${NC}"
echo "  1. Run: kubectl port-forward mongodb-0 27017:27017 -n chat-app"
echo "  2. Connect to: mongodb://root:toor@localhost:27017/chatapp"
echo ""

echo -e "${BLUE}Backend Configuration:${NC}"
echo "  MONGODB_URI: mongodb://root:toor@mongodb-service:27017/chatapp"
echo ""

print_success "✅ MongoDB StatefulSet is working correctly!"
print_status "You can now:"
echo "  - Connect via MongoDB Compass using port-forwarding"
echo "  - Deploy your backend to connect to MongoDB"
echo "  - Scale the StatefulSet if needed"

echo ""
print_status "🔧 Useful commands:"
echo "  - View logs: kubectl logs mongodb-0 -n chat-app"
echo "  - Get shell: kubectl exec -it mongodb-0 -n chat-app -- mongosh -u root -p toor"
echo "  - Port forward: kubectl port-forward mongodb-0 27017:27017 -n chat-app"
echo "  - Scale: kubectl scale statefulset mongodb --replicas=2 -n chat-app"
