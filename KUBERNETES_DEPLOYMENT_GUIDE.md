# Kubernetes Deployment Guide for Chat Application

## 📋 Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Pre-Deployment Setup](#pre-deployment-setup)
- [Deployment Steps](#deployment-steps)
- [Verification](#verification)
- [Accessing the Application](#accessing-the-application)
- [Troubleshooting](#troubleshooting)
- [Scaling](#scaling)
- [Cleanup](#cleanup)
- [Configuration Details](#configuration-details)

## 🔍 Overview

This guide provides step-by-step instructions for deploying a full-stack chat application on Kubernetes. The application consists of:

- **Frontend**: React-based chat interface served by Nginx
- **Backend**: Node.js/Express API with Socket.io for real-time messaging
- **Database**: MongoDB for data persistence
- **Ingress**: NGINX Ingress Controller for external access

## 📋 Prerequisites

### Required Tools
- **Kubernetes Cluster**: 
  - Local: Minikube, Kind, or Docker Desktop
  - Cloud: EKS, GKS, AKS, or any managed Kubernetes service
- **kubectl**: Kubernetes command-line tool
- **Docker**: For building custom images (if needed)

### Cluster Requirements
- **Minimum Resources**:
  - 2 CPU cores
  - 4GB RAM
  - 10GB storage
- **NGINX Ingress Controller** installed
- **DNS resolution** capability (for ingress)

### Verify Prerequisites
```bash
# Check kubectl connectivity
kubectl version --client

# Check cluster info
kubectl cluster-info

# Verify ingress controller
kubectl get pods -n ingress-nginx
```

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ingress       │    │   Frontend      │    │   Backend       │
│ (chat-tws.com)  │───▶│   (Nginx:80)    │───▶│ (Node.js:5001)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                              ┌─────────────────┐
                                              │   MongoDB       │
                                              │  (mongo:27017)  │
                                              └─────────────────┘
```

### Components Breakdown:
1. **Namespace**: `chat-app` - Isolates all resources
2. **Secrets**: JWT tokens and sensitive configuration
3. **Persistent Storage**: MongoDB data persistence
4. **Services**: Internal communication between components
5. **Ingress**: External access routing

## ⚙️ Pre-Deployment Setup

### 1. Enable Ingress (for Minikube)
```bash
# Enable ingress addon for Minikube
minikube addons enable ingress

# For other clusters, install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

### 2. Prepare Host Resolution
Add the following entry to your `/etc/hosts` file (or Windows equivalent):
```bash
# Get your cluster IP
minikube ip  # For Minikube
# OR for other setups
kubectl get ingress -n chat-app chatapp-ingress

# Add to /etc/hosts
<CLUSTER_IP> chat-tws.com
```

### 3. Verify Docker Images
Ensure the required images are available:
```bash
# Check if images exist in registry
docker pull rohankhanal14/chatapp-frontend:latest
docker pull rohankhanal14/chatapp-backend:latest
docker pull mongo:latest
```

## 🚀 Deployment Steps

### Step 1: Create Namespace
```bash
kubectl apply -f k8s/namespace.yml
```

**Verify:**
```bash
kubectl get namespaces | grep chat-app
```

### Step 2: Create Secrets
```bash
kubectl apply -f k8s/secrets.yml
```

**Verify:**
```bash
kubectl get secrets -n chat-app
kubectl describe secret chatapp-secrets -n chat-app
```

### Step 3: Setup MongoDB Storage
```bash
# Apply persistent volume
kubectl apply -f k8s/mongodb-pv.yml

# Apply persistent volume claim
kubectl apply -f k8s/mongodb-pvc.yml
```

**Verify:**
```bash
kubectl get pv mongodb-pv
kubectl get pvc -n chat-app mongodb-pvc
```

### Step 4: Deploy MongoDB
```bash
kubectl apply -f k8s/mongodb-deployment.yml
```

**Verify:**
```bash
kubectl get deployments -n chat-app mongodb-deployment
kubectl get pods -n chat-app | grep mongodb
```

**Wait for MongoDB to be ready:**
```bash
kubectl wait --for=condition=available --timeout=300s deployment/mongodb-deployment -n chat-app
```

### Step 5: Deploy Backend
```bash
kubectl apply -f k8s/backend-deployment.yml
kubectl apply -f k8s/backend-service.yml
```

**Verify:**
```bash
kubectl get deployments -n chat-app backend-deployment
kubectl get services -n chat-app backend
kubectl get pods -n chat-app | grep backend
```

**Wait for Backend to be ready:**
```bash
kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n chat-app
```

### Step 6: Deploy Frontend
```bash
kubectl apply -f k8s/frontend-deployment.yml
kubectl apply -f k8s/frontend-service.yml
```

**Verify:**
```bash
kubectl get deployments -n chat-app frontend-deployment
kubectl get services -n chat-app frontend
kubectl get pods -n chat-app | grep frontend
```

**Wait for Frontend to be ready:**
```bash
kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n chat-app
```

### Step 7: Setup Ingress
```bash
kubectl apply -f k8s/ingress.yml
```

**Verify:**
```bash
kubectl get ingress -n chat-app chatapp-ingress
kubectl describe ingress chatapp-ingress -n chat-app
```

### Complete Deployment Script
For convenience, you can run all deployments at once:
```bash
#!/bin/bash
echo "🚀 Deploying Chat Application to Kubernetes..."

# Apply all configurations in order
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/secrets.yml
kubectl apply -f k8s/mongodb-pv.yml
kubectl apply -f k8s/mongodb-pvc.yml
kubectl apply -f k8s/mongodb-deployment.yml

# Wait for MongoDB
kubectl wait --for=condition=available --timeout=300s deployment/mongodb-deployment -n chat-app

# Deploy backend
kubectl apply -f k8s/backend-deployment.yml
kubectl apply -f k8s/backend-service.yml

# Wait for backend
kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n chat-app

# Deploy frontend
kubectl apply -f k8s/frontend-deployment.yml
kubectl apply -f k8s/frontend-service.yml

# Wait for frontend
kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n chat-app

# Setup ingress
kubectl apply -f k8s/ingress.yml

echo "✅ Deployment completed!"
echo "🌐 Access the application at: http://chat-tws.com"
```

## ✅ Verification

### Check All Resources
```bash
# Overview of all resources
kubectl get all -n chat-app

# Detailed status
kubectl get pods,services,deployments,ingress,pvc,secrets -n chat-app
```

### Check Pod Health
```bash
# Check pod status
kubectl get pods -n chat-app -o wide

# Check pod logs
kubectl logs -f deployment/frontend-deployment -n chat-app
kubectl logs -f deployment/backend-deployment -n chat-app
kubectl logs -f deployment/mongodb-deployment -n chat-app
```

### Test Internal Connectivity
```bash
# Test backend service
kubectl exec -it deployment/frontend-deployment -n chat-app -- curl backend:5001/health

# Test MongoDB connection
kubectl exec -it deployment/backend-deployment -n chat-app -- nc -zv mongodb-deployment 27017
```

### Verify Ingress
```bash
# Check ingress status
kubectl get ingress -n chat-app

# Test external access
curl -H "Host: chat-tws.com" http://<CLUSTER_IP>
```

## 🌐 Accessing the Application

### Local Access (Minikube)
```bash
# Get Minikube IP
minikube ip

# Add to /etc/hosts
echo "$(minikube ip) chat-tws.com" | sudo tee -a /etc/hosts

# Access application
open http://chat-tws.com
```

### Port Forward (Alternative)
If ingress is not working, use port forwarding:
```bash
# Frontend
kubectl port-forward service/frontend 8080:80 -n chat-app

# Backend (for API testing)
kubectl port-forward service/backend 5001:5001 -n chat-app

# Access via localhost
open http://localhost:8080
```

### Cloud Provider Access
For cloud deployments, get the external IP:
```bash
kubectl get ingress -n chat-app chatapp-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Pods Not Starting
```bash
# Check pod events
kubectl describe pod <pod-name> -n chat-app

# Check resource limits
kubectl top pods -n chat-app
kubectl describe node
```

#### 2. Image Pull Errors
```bash
# Check image availability
docker pull rohankhanal14/chatapp-frontend:latest
docker pull rohankhanal14/chatapp-backend:latest

# Check image pull secrets if needed
kubectl get pods -n chat-app -o yaml | grep imagePullSecrets
```

#### 3. Service Connection Issues
```bash
# Test service DNS resolution
kubectl exec -it deployment/frontend-deployment -n chat-app -- nslookup backend

# Check service endpoints
kubectl get endpoints -n chat-app
```

#### 4. Persistent Volume Issues
```bash
# Check PV/PVC status
kubectl get pv,pvc -n chat-app
kubectl describe pvc mongodb-pvc -n chat-app

# Check node storage
df -h
```

#### 5. Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress rules
kubectl describe ingress chatapp-ingress -n chat-app

# Test without host header
curl http://<CLUSTER_IP>
```

### Debug Commands
```bash
# Get detailed logs
kubectl logs deployment/backend-deployment -n chat-app --previous
kubectl logs deployment/frontend-deployment -n chat-app --since=1h

# Execute into containers
kubectl exec -it deployment/backend-deployment -n chat-app -- /bin/bash
kubectl exec -it deployment/mongodb-deployment -n chat-app -- mongo

# Check environment variables
kubectl exec deployment/backend-deployment -n chat-app -- env
```

### Resource Monitoring
```bash
# Resource usage
kubectl top pods -n chat-app
kubectl top nodes

# Events
kubectl get events -n chat-app --sort-by='.lastTimestamp'
```

## 📈 Scaling

### Horizontal Scaling
```bash
# Scale frontend
kubectl scale deployment frontend-deployment --replicas=3 -n chat-app

# Scale backend
kubectl scale deployment backend-deployment --replicas=2 -n chat-app

# Check scaling status
kubectl get deployments -n chat-app
```

### Autoscaling (HPA)
Create a Horizontal Pod Autoscaler:
```bash
# Enable metrics server (if not present)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Create HPA for backend
kubectl autoscale deployment backend-deployment --cpu-percent=70 --min=1 --max=5 -n chat-app

# Create HPA for frontend
kubectl autoscale deployment frontend-deployment --cpu-percent=70 --min=1 --max=3 -n chat-app

# Check HPA status
kubectl get hpa -n chat-app
```

### Resource Limits
Add resource limits to deployments:
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

## 🧹 Cleanup

### Complete Cleanup
```bash
# Delete all resources in namespace
kubectl delete namespace chat-app

# Delete persistent volume (if needed)
kubectl delete pv mongodb-pv

# Clean up host file
sudo sed -i '/chat-tws.com/d' /etc/hosts
```

### Selective Cleanup
```bash
# Delete specific components
kubectl delete -f k8s/ingress.yml
kubectl delete -f k8s/frontend-deployment.yml
kubectl delete -f k8s/frontend-service.yml
kubectl delete -f k8s/backend-deployment.yml
kubectl delete -f k8s/backend-service.yml
kubectl delete -f k8s/mongodb-deployment.yml

# Keep storage for data persistence
# kubectl delete -f k8s/mongodb-pvc.yml
# kubectl delete -f k8s/mongodb-pv.yml
```

## ⚙️ Configuration Details

### Environment Variables

#### Backend Configuration
- `NODE_ENV`: Set to "production"
- `MONGODB_URI`: MongoDB connection string
- `JWT_SECRET`: JWT signing secret (from Kubernetes Secret)
- `PORT`: Backend port (5001)

#### Frontend Configuration
- `NODE_ENV`: Set to "production"

### Security Considerations

#### JWT Secret
The JWT secret is base64 encoded in the Kubernetes secret. To update:
```bash
# Generate new JWT secret
echo -n "your-new-jwt-secret" | base64

# Update secret
kubectl patch secret chatapp-secrets -n chat-app -p='{"data":{"jwt":"<BASE64_ENCODED_SECRET>"}}'
```

#### Network Policies
Consider implementing network policies for enhanced security:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: chat-app-network-policy
  namespace: chat-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  egress:
  - {}
```

### Storage Considerations

#### MongoDB Persistence
- **Volume Type**: hostPath (for local development)
- **Size**: 5Gi
- **Access Mode**: ReadWriteOnce

For production, consider:
- Using cloud-managed databases
- Implementing backup strategies
- Using dynamic provisioning

### Performance Tuning

#### Resource Allocation
Monitor and adjust resource requests/limits based on usage:
```bash
# Monitor resource usage
kubectl top pods -n chat-app --containers
kubectl describe node
```

#### Database Optimization
- Configure MongoDB with appropriate settings for your workload
- Consider using MongoDB replica sets for high availability
- Implement proper indexing strategies

## 📝 Additional Notes

### Development vs Production
This configuration is suitable for development and testing. For production:

1. **Use managed databases** (e.g., MongoDB Atlas, AWS DocumentDB)
2. **Implement proper secrets management** (e.g., AWS Secrets Manager, HashiCorp Vault)
3. **Add TLS/SSL termination**
4. **Configure resource limits and requests**
5. **Implement health checks and probes**
6. **Set up monitoring and logging**
7. **Configure backup strategies**

### Monitoring Integration
Consider integrating with monitoring solutions:
- **Prometheus** for metrics collection
- **Grafana** for visualization
- **ELK Stack** for logging
- **Jaeger** for distributed tracing

### CI/CD Integration
This setup can be integrated with CI/CD pipelines using tools like:
- **Jenkins** (Jenkinsfile present in the project)
- **GitHub Actions**
- **GitLab CI**
- **ArgoCD** for GitOps

---

## 🤝 Support

If you encounter issues during deployment:

1. Check the troubleshooting section
2. Verify all prerequisites are met
3. Review Kubernetes cluster resources
4. Check application logs for specific errors
5. Ensure all Docker images are accessible

For additional support, please refer to the main project documentation or create an issue in the project repository.

---

Run the deploy.sh for deployment automation 

```bash

./deploy.sh         # Deploy the application
./deploy.sh status  # Show deployment status
./deploy.sh health  # Run health checks
./deploy.sh access  # Show access information
./deploy.sh cleanup # Remove all resources
./deploy.sh help    # Show help

```

**Happy Deploying! 🚀**
