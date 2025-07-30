#!/bin/bash

# Kubernetes Chat Application Deployment Script
# This script deploys the full-stack chat application to Kubernetes

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_success "kubectl is available"
}

# Function to check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_status "Please ensure your cluster is running and kubectl is configured"
        exit 1
    fi
    print_success "Kubernetes cluster is accessible"
}

# Function to check if k8s directory exists
check_k8s_files() {
    if [ ! -d "k8s" ]; then
        print_error "k8s directory not found"
        print_status "Please run this script from the project root directory"
        exit 1
    fi

    local required_files=(
        "k8s/namespace.yml"
        "k8s/secrets.yml"
        "k8s/mongodb-deployment.yml"
        "k8s/mongodb-headless-service.yml"
        "k8s/mongodb-service.yml"
        "k8s/backend-deployment.yml"
        "k8s/backend-service.yml"
        "k8s/frontend-deployment.yml"
        "k8s/frontend-service.yml"
        "k8s/ingress.yml"
    )

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file $file not found"
            exit 1
        fi
    done
    print_success "All required Kubernetes files found"
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}
    
    print_status "Waiting for deployment $deployment to be ready..."
    if kubectl wait --for=condition=available --timeout=${timeout}s deployment/$deployment -n $namespace; then
        print_success "Deployment $deployment is ready"
    else
        print_error "Deployment $deployment failed to become ready within ${timeout} seconds"
        print_status "Checking pod status..."
        kubectl get pods -n $namespace | grep $deployment
        kubectl describe deployment $deployment -n $namespace
        exit 1
    fi
}

# Function to wait for StatefulSet to be ready
wait_for_statefulset() {
    local statefulset=$1
    local namespace=$2
    local timeout=${3:-300}
    
    print_status "Waiting for StatefulSet $statefulset to be ready..."
    if kubectl wait --for=condition=ready --timeout=${timeout}s pod/${statefulset}-0 -n $namespace; then
        print_success "StatefulSet $statefulset is ready"
    else
        print_error "StatefulSet $statefulset failed to become ready within ${timeout} seconds"
        print_status "Checking pod status..."
        kubectl get pods -n $namespace | grep $statefulset
        kubectl describe statefulset $statefulset -n $namespace
        exit 1
    fi
}

# Function to check if ingress controller is available
check_ingress_controller() {
    print_status "Checking for ingress controller..."
    if kubectl get pods -n ingress-nginx 2>/dev/null | grep -q "ingress-nginx-controller"; then
        print_success "NGINX Ingress Controller found"
    else
        print_warning "NGINX Ingress Controller not found"
        print_status "You may need to install it or enable it for Minikube:"
        print_status "  For Minikube: minikube addons enable ingress"
        print_status "  For other clusters: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Main deployment function
deploy_application() {
    print_header "🚀 Deploying Chat Application to Kubernetes"
    
    # Step 1: Create Namespace
    print_status "Creating namespace..."
    kubectl apply -f k8s/namespace.yml
    print_success "Namespace created"
    
    # Step 2: Create Secrets
    print_status "Creating secrets..."
    kubectl apply -f k8s/secrets.yml
    print_success "Secrets created"
    
    # Step 3: Deploy MongoDB StatefulSet
    print_status "Deploying MongoDB StatefulSet..."
    kubectl apply -f k8s/mongodb-deployment.yml
    
    print_status "Creating MongoDB services..."
    kubectl apply -f k8s/mongodb-headless-service.yml
    kubectl apply -f k8s/mongodb-service.yml
    
    wait_for_statefulset "mongodb" "chat-app" 300
    
    # Step 4: Deploy Backend
    print_status "Deploying backend service..."
    kubectl apply -f k8s/backend-deployment.yml
    kubectl apply -f k8s/backend-service.yml
    wait_for_deployment "backend-deployment" "chat-app" 300
    
    # Step 5: Deploy Frontend
    print_status "Deploying frontend service..."
    kubectl apply -f k8s/frontend-deployment.yml
    kubectl apply -f k8s/frontend-service.yml
    wait_for_deployment "frontend-deployment" "chat-app" 300
    
    # Step 6: Setup Ingress
    print_status "Setting up ingress..."
    kubectl apply -f k8s/ingress.yml
    print_success "Ingress configured"
    
    print_success "✅ Deployment completed!"
}

# Function to show deployment status
show_status() {
    print_header "📊 Deployment Status"
    
    print_status "Namespace:"
    kubectl get namespace chat-app
    echo
    
    print_status "All resources in chat-app namespace:"
    kubectl get all -n chat-app
    echo
    
    print_status "Persistent Volume Claims:"
    kubectl get pvc -n chat-app
    echo
    
    print_status "Secrets:"
    kubectl get secrets -n chat-app
    echo
    
    print_status "Ingress:"
    kubectl get ingress -n chat-app
    echo
}

# Function to show access instructions
show_access_info() {
    print_header "🌐 Access Information"
    
    # Check if we're using Minikube
    if command -v minikube &> /dev/null && minikube status &> /dev/null; then
        local minikube_ip=$(minikube ip 2>/dev/null || echo "Unable to get Minikube IP")
        print_status "Minikube detected. Cluster IP: $minikube_ip"
        print_status "Add this to your /etc/hosts file:"
        echo "    $minikube_ip chat-tws.com"
        echo
        print_status "To add automatically:"
        echo "    echo \"$minikube_ip chat-tws.com\" | sudo tee -a /etc/hosts"
        echo
        print_success "Then access the application at: http://chat-tws.com"
    else
        local ingress_ip=$(kubectl get ingress -n chat-app chatapp-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending")
        print_status "Ingress IP: $ingress_ip"
        if [ "$ingress_ip" != "Pending" ] && [ "$ingress_ip" != "" ]; then
            print_status "Add this to your /etc/hosts file:"
            echo "    $ingress_ip chat-tws.com"
            echo
            print_success "Then access the application at: http://chat-tws.com"
        else
            print_warning "Ingress IP is still pending. You can use port forwarding instead:"
            echo "    kubectl port-forward service/frontend 8080:80 -n chat-app"
            echo "    Then access at: http://localhost:8080"
        fi
    fi
    
    echo
    print_status "Alternative access methods:"
    echo "  Frontend port-forward: kubectl port-forward service/frontend 8080:80 -n chat-app"
    echo "  Backend port-forward:  kubectl port-forward service/backend 5001:5001 -n chat-app"
    echo "  MongoDB port-forward:  kubectl port-forward service/mongodb 27017:27017 -n chat-app"
}

# Function to run basic health checks
run_health_checks() {
    print_header "🏥 Health Checks"
    
    print_status "Checking pod health..."
    local unhealthy_pods=$(kubectl get pods -n chat-app --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    
    if [ "$unhealthy_pods" -eq 0 ]; then
        print_success "All pods are running"
        kubectl get pods -n chat-app
    else
        print_warning "Some pods are not running:"
        kubectl get pods -n chat-app
        echo
        print_status "Pod details:"
        kubectl describe pods -n chat-app | grep -A 10 -B 5 "Events:"
    fi
    
    echo
    print_status "Checking service endpoints..."
    kubectl get endpoints -n chat-app
}

# Cleanup function
cleanup() {
    print_header "🧹 Cleanup"
    print_warning "This will delete all chat-app resources"
    read -p "Are you sure you want to cleanup? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deleting namespace and all resources..."
        kubectl delete namespace chat-app
        kubectl delete pv mongodb-pv 2>/dev/null || true
        print_success "Cleanup completed"
        
        print_status "Don't forget to remove the host entry:"
        echo "    sudo sed -i '/chat-tws.com/d' /etc/hosts"
    else
        print_status "Cleanup cancelled"
    fi
}

# Help function
show_help() {
    echo "Kubernetes Chat Application Deployment Script"
    echo
    echo "Usage: $0 [OPTION]"
    echo
    echo "Options:"
    echo "  deploy    Deploy the application (default)"
    echo "  status    Show deployment status"
    echo "  health    Run health checks"
    echo "  access    Show access information"
    echo "  cleanup   Remove all resources"
    echo "  help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0                # Deploy the application"
    echo "  $0 deploy         # Deploy the application"
    echo "  $0 status         # Show current status"
    echo "  $0 cleanup        # Clean up all resources"
}

# Main script logic
main() {
    local action=${1:-deploy}
    
    case $action in
        "deploy")
            check_kubectl
            check_cluster
            check_k8s_files
            check_ingress_controller
            deploy_application
            echo
            show_status
            echo
            show_access_info
            echo
            run_health_checks
            ;;
        "status")
            check_kubectl
            check_cluster
            show_status
            ;;
        "health")
            check_kubectl
            check_cluster
            run_health_checks
            ;;
        "access")
            check_kubectl
            check_cluster
            show_access_info
            ;;
        "cleanup")
            check_kubectl
            check_cluster
            cleanup
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown option: $action"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
