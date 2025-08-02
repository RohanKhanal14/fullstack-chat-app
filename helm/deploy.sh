#!/bin/bash

# ChatApp Helm Deployment Script
# This script provides an easy way to deploy the ChatApp using Helm

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
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

# Default values
RELEASE_NAME="chatapp"
NAMESPACE="chat-app"
CHART_PATH="./helm/chatapp"
ACTION="install"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -a, --action ACTION     Action to perform (install, upgrade, uninstall, status) [default: install]"
    echo "  -r, --release RELEASE   Release name [default: chatapp]"
    echo "  -n, --namespace NS      Namespace [default: chat-app]"
    echo "  -f, --values FILE       Custom values file"
    echo "  --dry-run              Perform a dry run"
    echo "  --debug                Enable debug output"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Install with default values"
    echo "  $0 -a upgrade                         # Upgrade existing installation"
    echo "  $0 -a uninstall                       # Uninstall the application"
    echo "  $0 -f custom-values.yaml              # Install with custom values"
    echo "  $0 --dry-run                          # Test installation without deploying"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if kubectl is available and configured
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if chart directory exists
    if [ ! -d "$CHART_PATH" ]; then
        print_error "Helm chart not found at $CHART_PATH"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to install the application
install_app() {
    print_info "Installing ChatApp..."
    
    # Lint the chart first
    print_info "Linting Helm chart..."
    if ! helm lint "$CHART_PATH"; then
        print_error "Helm chart linting failed"
        exit 1
    fi
    
    # Build helm command
    local cmd="helm install $RELEASE_NAME $CHART_PATH"
    
    if [ -n "$VALUES_FILE" ]; then
        cmd="$cmd -f $VALUES_FILE"
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        cmd="$cmd --dry-run"
    fi
    
    if [ "$DEBUG" = "true" ]; then
        cmd="$cmd --debug"
    fi
    
    # Execute the command
    if eval "$cmd"; then
        if [ "$DRY_RUN" != "true" ]; then
            print_success "ChatApp installed successfully!"
            show_status
        else
            print_success "Dry run completed successfully!"
        fi
    else
        print_error "Installation failed"
        exit 1
    fi
}

# Function to upgrade the application
upgrade_app() {
    print_info "Upgrading ChatApp..."
    
    # Build helm command
    local cmd="helm upgrade $RELEASE_NAME $CHART_PATH"
    
    if [ -n "$VALUES_FILE" ]; then
        cmd="$cmd -f $VALUES_FILE"
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        cmd="$cmd --dry-run"
    fi
    
    if [ "$DEBUG" = "true" ]; then
        cmd="$cmd --debug"
    fi
    
    # Execute the command
    if eval "$cmd"; then
        if [ "$DRY_RUN" != "true" ]; then
            print_success "ChatApp upgraded successfully!"
            show_status
        else
            print_success "Dry run completed successfully!"
        fi
    else
        print_error "Upgrade failed"
        exit 1
    fi
}

# Function to uninstall the application
uninstall_app() {
    print_warning "This will uninstall ChatApp and remove all associated resources."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    print_info "Uninstalling ChatApp..."
    
    if helm uninstall "$RELEASE_NAME"; then
        print_success "ChatApp uninstalled successfully!"
        
        # Ask if user wants to delete the namespace
        read -p "Do you want to delete the namespace '$NAMESPACE'? (y/N): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
            print_success "Namespace '$NAMESPACE' deleted"
        fi
    else
        print_error "Uninstallation failed"
        exit 1
    fi
}

# Function to show status
show_status() {
    print_info "ChatApp Status:"
    echo ""
    
    # Helm release status
    print_info "Helm Release Status:"
    helm status "$RELEASE_NAME" 2>/dev/null || print_warning "Release '$RELEASE_NAME' not found"
    echo ""
    
    # Pod status
    print_info "Pod Status:"
    kubectl get pods -n "$NAMESPACE" 2>/dev/null || print_warning "Namespace '$NAMESPACE' not found"
    echo ""
    
    # Service status
    print_info "Service Status:"
    kubectl get services -n "$NAMESPACE" 2>/dev/null || print_warning "No services found in namespace '$NAMESPACE'"
    echo ""
    
    # Ingress status
    print_info "Ingress Status:"
    kubectl get ingress -n "$NAMESPACE" 2>/dev/null || print_warning "No ingress found in namespace '$NAMESPACE'"
    echo ""
    
    # Show application URLs
    print_info "Application Access:"
    echo "To access the application, you can use port forwarding:"
    echo "  kubectl port-forward -n $NAMESPACE service/$RELEASE_NAME-frontend 8080:80"
    echo "  kubectl port-forward -n $NAMESPACE service/$RELEASE_NAME-backend 8081:5001"
    echo ""
    echo "Then visit:"
    echo "  Frontend: http://localhost:8080"
    echo "  Backend:  http://localhost:8081"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --debug)
            DEBUG="true"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
print_info "ChatApp Helm Deployment Script"
print_info "Action: $ACTION"
print_info "Release: $RELEASE_NAME"
print_info "Namespace: $NAMESPACE"
echo ""

case $ACTION in
    install)
        check_prerequisites
        install_app
        ;;
    upgrade)
        check_prerequisites
        upgrade_app
        ;;
    uninstall)
        uninstall_app
        ;;
    status)
        show_status
        ;;
    *)
        print_error "Invalid action: $ACTION"
        print_error "Valid actions are: install, upgrade, uninstall, status"
        exit 1
        ;;
esac
