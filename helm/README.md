# ChatApp Helm Deployment Guide

This repository contains a Helm chart for deploying the ChatApp application, which consists of a React frontend and Node.js backend, using an external MongoDB Atlas database.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Helm Chart Structure](#helm-chart-structure)
4. [Configuration](#configuration)
5. [Installation](#installation)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)
8. [Customization](#customization)
9. [Uninstallation](#uninstallation)
10. [Production Considerations](#production-considerations)

## 🔧 Prerequisites

Before deploying the ChatApp using Helm, ensure you have the following:

### Required Tools
- **Kubernetes cluster** (v1.19+)
  - Minikube, Kind, EKS, GKE, AKS, or any other Kubernetes distribution
- **Helm** (v3.0+)
  ```bash
  # Install Helm on Linux
  curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz | tar xz
  sudo mv linux-amd64/helm /usr/local/bin/helm
  
  # Verify installation
  helm version
  ```
- **kubectl** configured to access your cluster
  ```bash
  kubectl cluster-info
  ```
- **NGINX Ingress Controller** (if using ingress)
  ```bash
  # Install NGINX Ingress Controller
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
  ```

### External Dependencies
- **MongoDB Atlas Database**
  - Connection string: `mongodb+srv://root:toor@cluster0.oadytbk.mongodb.net/`
  - Ensure the database is accessible from your Kubernetes cluster
  - Whitelist your cluster's IP addresses in MongoDB Atlas

### Docker Images
The following Docker images should be available:
- `rohankhanal14/chatapp-frontend:latest`
- `rohankhanal14/chatapp-backend:latest`

## 🏗️ Architecture Overview

The ChatApp deployment consists of:

```
┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │
│    Frontend     │    │     Backend     │
│   (React App)   │    │   (Node.js)     │
│                 │    │                 │
│  Port: 80       │    │  Port: 5001     │
│                 │    │                 │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌─────────────────┐
         │                 │
         │     Ingress     │
         │  (chat-tws.com) │
         │                 │
         └─────────────────┘
                     │
              ┌─────────────────┐
              │                 │
              │  MongoDB Atlas  │
              │   (External)    │
              │                 │
              └─────────────────┘
```

### Components Deployed:
- **Namespace**: `chat-app`
- **Frontend Deployment**: React application served by NGINX
- **Backend Deployment**: Node.js API server
- **Frontend Service**: ClusterIP service for internal communication
- **Backend Service**: ClusterIP service for internal communication
- **ConfigMap**: Application configuration
- **Secret**: Sensitive data (JWT secret, MongoDB connection string)
- **Ingress**: External access routing

## 📁 Helm Chart Structure

```
helm/chatapp/
├── Chart.yaml                           # Chart metadata
├── values.yaml                          # Default configuration values
├── templates/
│   ├── namespace.yaml                   # Namespace creation
│   ├── configmap.yaml                   # Application configuration
│   ├── secret.yaml                      # Sensitive data
│   ├── frontend-deployment.yaml        # Frontend deployment
│   ├── frontend-service.yaml          # Frontend service
│   ├── backend-deployment.yaml        # Backend deployment
│   ├── backend-service.yaml           # Backend service
│   ├── ingress.yaml                    # Ingress routing
│   ├── NOTES.txt                       # Post-installation notes
│   ├── _helpers.tpl                    # Template helpers
│   └── tests/
│       └── test-connection.yaml        # Connection test
└── .helmignore                         # Files to ignore during packaging
```

## ⚙️ Configuration

### Default Values (`values.yaml`)

The chart uses the following default configuration:

```yaml
# Namespace
namespace: chat-app

# Global settings
global:
  nodeEnv: "production"

# Frontend configuration
frontend:
  replicaCount: 1
  image:
    repository: rohankhanal14/chatapp-frontend
    tag: "latest"
  service:
    type: ClusterIP
    port: 80
  resources:
    limits:
      cpu: 500m
      memory: 128Mi
    requests:
      cpu: 250m
      memory: 64Mi

# Backend configuration
backend:
  replicaCount: 1
  image:
    repository: rohankhanal14/chatapp-backend
    tag: "latest"
  service:
    type: ClusterIP
    port: 5001
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi

# Database connection
mongodb:
  connectionString: "mongodb+srv://root:toor@cluster0.oadytbk.mongodb.net/"

# Ingress
ingress:
  enabled: true
  hosts:
    - host: chat-tws.com
      paths:
        - path: /
          pathType: Prefix
          service: frontend
        - path: /api
          pathType: Prefix
          service: backend
```

## 🚀 Installation

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd chatApp_k8s
```

### Step 2: Verify Helm Chart

```bash
# Lint the chart for syntax errors
helm lint ./helm/chatapp

# Test with dry run
helm install chatapp-test ./helm/chatapp --dry-run --debug
```

### Step 3: Install the Chart

#### Option A: Install with Default Values
```bash
helm install chatapp ./helm/chatapp
```

#### Option B: Install with Custom Values
```bash
# Create a custom values file
cat > custom-values.yaml << EOF
namespace: my-chat-app

frontend:
  replicaCount: 2
  image:
    tag: "v1.0.0"

backend:
  replicaCount: 2
  image:
    tag: "v1.0.0"

ingress:
  hosts:
    - host: my-chat.example.com
      paths:
        - path: /
          pathType: Prefix
          service: frontend
        - path: /api
          pathType: Prefix
          service: backend
EOF

# Install with custom values
helm install chatapp ./helm/chatapp -f custom-values.yaml
```

#### Option C: Install with Command Line Overrides
```bash
helm install chatapp ./helm/chatapp \
  --set namespace=my-chat-app \
  --set frontend.replicaCount=2 \
  --set backend.replicaCount=2 \
  --set ingress.hosts[0].host=my-chat.example.com
```

### Step 4: Check Installation Status

```bash
# Check Helm release status
helm status chatapp

# List all releases
helm list

# Get detailed information
helm get all chatapp
```

## ✅ Verification

### Step 1: Check Pod Status

```bash
# Check all pods in the namespace
kubectl get pods -n chat-app

# Check pod details
kubectl describe pods -n chat-app

# Check pod logs
kubectl logs -l app.kubernetes.io/component=frontend -n chat-app
kubectl logs -l app.kubernetes.io/component=backend -n chat-app
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE
chatapp-backend-xxxxxxxxx-xxxxx    1/1     Running   0          2m
chatapp-frontend-xxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### Step 2: Check Services

```bash
# Check services
kubectl get services -n chat-app

# Check service endpoints
kubectl get endpoints -n chat-app
```

Expected output:
```
NAME                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
chatapp-backend     ClusterIP   10.96.xxx.xxx    <none>        5001/TCP   2m
chatapp-frontend    ClusterIP   10.96.xxx.xxx    <none>        80/TCP     2m
```

### Step 3: Check Ingress

```bash
# Check ingress
kubectl get ingress -n chat-app

# Check ingress details
kubectl describe ingress -n chat-app
```

### Step 4: Test Application

#### Option A: Using Ingress (if configured)
```bash
# Add host entry to /etc/hosts (for local testing)
echo "$(kubectl get ingress chatapp-ingress -n chat-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}') chat-tws.com" | sudo tee -a /etc/hosts

# Access the application
curl http://chat-tws.com
curl http://chat-tws.com/api/health
```

#### Option B: Using Port Forwarding
```bash
# Forward frontend port
kubectl port-forward -n chat-app service/chatapp-frontend 8080:80

# Forward backend port (in another terminal)
kubectl port-forward -n chat-app service/chatapp-backend 8081:5001

# Test the application
curl http://localhost:8080
curl http://localhost:8081/api/health
```

### Step 5: Run Helm Tests

```bash
# Run the built-in connection test
helm test chatapp
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name> -n chat-app

# Check logs
kubectl logs <pod-name> -n chat-app

# Common causes:
# - Image pull errors
# - Resource constraints
# - ConfigMap/Secret issues
```

#### 2. Database Connection Issues

```bash
# Check if MongoDB connection string is correct
kubectl get secret chatapp-secrets -n chat-app -o yaml
echo "<base64-encoded-value>" | base64 -d

# Test connectivity from a pod
kubectl run -it --rm debug --image=busybox --restart=Never -n chat-app -- sh
# Inside the pod:
nslookup cluster0.oadytbk.mongodb.net
```

#### 3. Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress events
kubectl describe ingress chatapp-ingress -n chat-app

# Verify DNS resolution
nslookup chat-tws.com
```

#### 4. Service Discovery Issues

```bash
# Check DNS resolution within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -n chat-app -- sh
# Inside the pod:
nslookup chatapp-frontend.chat-app.svc.cluster.local
nslookup chatapp-backend.chat-app.svc.cluster.local
```

### Debug Commands

```bash
# Get all resources in namespace
kubectl get all -n chat-app

# Check resource usage
kubectl top pods -n chat-app
kubectl top nodes

# Check events
kubectl get events -n chat-app --sort-by='.lastTimestamp'

# Exec into pods for debugging
kubectl exec -it <pod-name> -n chat-app -- sh
```

## 🎛️ Customization

### Scaling the Application

```bash
# Scale frontend
helm upgrade chatapp ./helm/chatapp --set frontend.replicaCount=3

# Scale backend
helm upgrade chatapp ./helm/chatapp --set backend.replicaCount=2

# Scale both
helm upgrade chatapp ./helm/chatapp \
  --set frontend.replicaCount=3 \
  --set backend.replicaCount=2
```

### Updating Images

```bash
# Update to specific versions
helm upgrade chatapp ./helm/chatapp \
  --set frontend.image.tag=v2.0.0 \
  --set backend.image.tag=v2.0.0
```

### Resource Management

```bash
# Increase resources for production
helm upgrade chatapp ./helm/chatapp \
  --set backend.resources.limits.memory=1Gi \
  --set backend.resources.limits.cpu=1000m \
  --set frontend.resources.limits.memory=256Mi
```

### Environment Configuration

```bash
# Change to development environment
helm upgrade chatapp ./helm/chatapp \
  --set global.nodeEnv=development
```

## 🗑️ Uninstallation

### Complete Removal

```bash
# Uninstall the Helm release
helm uninstall chatapp

# Verify removal
helm list

# Check remaining resources
kubectl get all -n chat-app

# Remove namespace if needed
kubectl delete namespace chat-app
```

### Selective Removal

```bash
# Remove only specific components
kubectl delete deployment chatapp-frontend -n chat-app
kubectl delete service chatapp-frontend -n chat-app
```

## 🏭 Production Considerations

### Security

1. **Use secrets management:**
   ```bash
   # Use external secret management (e.g., Vault, AWS Secrets Manager)
   # Don't store secrets in values.yaml in production
   ```

2. **Network policies:**
   ```yaml
   # Add network policies to restrict traffic
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: chatapp-network-policy
     namespace: chat-app
   spec:
     podSelector:
       matchLabels:
         app.kubernetes.io/name: chatapp
     policyTypes:
     - Ingress
     - Egress
   ```

3. **Pod security contexts:**
   ```bash
   # Add security contexts to values.yaml
   helm upgrade chatapp ./helm/chatapp \
     --set podSecurityContext.runAsNonRoot=true \
     --set podSecurityContext.runAsUser=1000
   ```

### High Availability

1. **Multiple replicas:**
   ```bash
   helm upgrade chatapp ./helm/chatapp \
     --set frontend.replicaCount=3 \
     --set backend.replicaCount=3
   ```

2. **Pod disruption budgets:**
   ```yaml
   # Add to templates/
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: chatapp-pdb
   spec:
     minAvailable: 2
     selector:
       matchLabels:
         app.kubernetes.io/name: chatapp
   ```

3. **Anti-affinity rules:**
   ```bash
   # Spread pods across nodes
   helm upgrade chatapp ./helm/chatapp \
     --set affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution[0].weight=100
   ```

### Monitoring

1. **Health checks:**
   ```yaml
   # Add to deployment templates
   livenessProbe:
     httpGet:
       path: /health
       port: http
     initialDelaySeconds: 30
     periodSeconds: 10
   
   readinessProbe:
     httpGet:
       path: /ready
       port: http
     initialDelaySeconds: 5
     periodSeconds: 5
   ```

2. **Metrics collection:**
   ```bash
   # Install Prometheus and Grafana
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install monitoring prometheus-community/kube-prometheus-stack
   ```

### Backup and Recovery

1. **Database backups:**
   ```bash
   # Ensure MongoDB Atlas automated backups are enabled
   # Implement application-level backup strategies
   ```

2. **Configuration backups:**
   ```bash
   # Backup Helm values
   helm get values chatapp > chatapp-backup-values.yaml
   
   # Backup Kubernetes resources
   kubectl get all -n chat-app -o yaml > chatapp-backup.yaml
   ```

### Performance Optimization

1. **Resource tuning:**
   ```bash
   # Set appropriate resource requests and limits
   # Monitor actual usage and adjust accordingly
   kubectl top pods -n chat-app
   ```

2. **Horizontal Pod Autoscaling:**
   ```yaml
   # Add HPA
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: chatapp-hpa
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: chatapp-backend
     minReplicas: 2
     maxReplicas: 10
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
   ```

## 📞 Support

For issues and support:

1. Check the [troubleshooting section](#troubleshooting)
2. Review Kubernetes and Helm documentation
3. Check application logs and events
4. Consult MongoDB Atlas documentation for database issues

## 📝 Notes

- This deployment uses an external MongoDB Atlas database
- The JWT secret is base64 encoded in the values.yaml
- Ingress is configured for `chat-tws.com` - update this for your domain
- All pods run in the `chat-app` namespace by default
- The chart follows Helm best practices and Kubernetes conventions

---

**Happy deploying! 🚀**
