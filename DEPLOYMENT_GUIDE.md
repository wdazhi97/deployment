# Snake Game Microservices - Deployment Guide

## Overview
This guide provides instructions for deploying the Snake Game microservices with the refactored Clean Architecture and multi-environment support.

## Services Architecture
- **API Gateway** (port 8080) - HTTP API gateway
- **Lobby Service** (port 50051) - User authentication and profiles
- **Matching Service** (port 50052) - Player matching
- **Room Service** (port 50053) - Room management (stateful, in-memory)
- **Leaderboard Service** (port 50054) - Score management (database)
- **Game Service** (port 50055) - Game state management (stateful, in-memory)
- **Friends Service** (port 50056) - Friend management (database)
- **MongoDB** - Data persistence

## Multi-Environment Configuration

The deployment supports three distinct environments:

### Debug Environment
- **Namespace**: `snake-game-debug`
- **Replicas**: Minimal (1-1 for most services)
- **Logging**: `debug` level
- **Resources**: Lower limits for development
- **Purpose**: Development and debugging

### Test Environment
- **Namespace**: `snake-game-test`
- **Replicas**: Moderate (2-2 for most services)
- **Logging**: `info` level
- **Resources**: Medium allocation
- **Purpose**: Integration testing and QA

### Release Environment
- **Namespace**: `snake-game-release`
- **Replicas**: High availability (3+ replicas)
- **Logging**: `warn` level
- **Resources**: Full production allocation
- **Purpose**: Production deployment

## Prerequisites
- Kubernetes cluster
- Docker
- kubectl
- kustomize (for advanced deployments)
- Helm (optional)

## Building Container Images

### 1. Navigate to the server directory:
```bash
cd /data/workspace/server_go
```

### 2. Build the Docker image:
```bash
docker build -t server_go:latest .
```

### 3. If using a remote Kubernetes cluster, push the image to a registry:
```bash
# Tag and push to your registry
docker tag server_go:latest <your-registry>/server_go:latest
docker push <your-registry>/server_go:latest
```

Then update the image reference in the deployment files:
```bash
sed -i 's|server_go:latest|<your-registry>/server_go:latest|g' /data/workspace/deployment/*/deployment.yaml
```

## Deploying with Multi-Environment Script (Recommended)

### 1. Make the script executable:
```bash
chmod +x /data/workspace/deployment/deploy-env.sh
```

### 2. Deploy to debug environment:
```bash
./deploy-env.sh all debug
```

### 3. Deploy to test environment:
```bash
./deploy-env.sh all test
```

### 4. Deploy to release environment:
```bash
./deploy-env.sh all release
```

## Deploying with Kubectl (Single Environment)

### 1. Create a dedicated namespace for the application:
```bash
kubectl create namespace snake-game
```

### 2. Apply the MongoDB deployment first:
```bash
kubectl apply -f /data/workspace/deployment/mongodb/mongodb-deployment.yaml -n snake-game
```

### 3. Wait for MongoDB to be ready:
```bash
kubectl get pods -l app=mongodb -n snake-game
```

### 4. Deploy all services to the snake-game namespace:
```bash
kubectl apply -f /data/workspace/deployment/lobby/lobby-deployment.yaml -n snake-game
kubectl apply -f /data/workspace/deployment/matching/matching-deployment.yaml -n snake-game
kubectl apply -f /data/workspace/deployment/room/room-deployment.yaml -n snake-game
kubectl apply -f /data/workspace/deployment/leaderboard/leaderboard-deployment.yaml -n snake-game
kubectl apply -f /data/workspace/deployment/game/game-deployment.yaml -n snake-game
kubectl apply -f /data/workspace/deployment/friends/friends-deployment.yaml -n snake-game
kubectl apply -f /data/workspace/deployment/gateway/gateway-deployment.yaml -n snake-game
```

### 5. Verify all deployments:
```bash
kubectl get deployments -n snake-game
kubectl get services -n snake-game
kubectl get pods -n snake-game
```

## Deploying with Kustomize (Environment-Specific)

### 1. Deploy to specific environment:
```bash
# Deploy debug environment
kubectl apply -k /data/workspace/deployment/env/debug/overlay/

# Deploy test environment
kubectl apply -k /data/workspace/deployment/env/test/overlay/

# Deploy release environment
kubectl apply -k /data/workspace/deployment/env/release/overlay/
```

### 2. The kustomize configuration will automatically create the environment-specific namespace and deploy all services with environment-specific configurations.

## Deploying with Helm

### 1. Update the values.yaml if using a custom image registry:
```bash
# Edit /data/workspace/deployment/helm/snake-game/values.yaml
# Change the image.repository and image.tag values as needed
```

### 2. Install the Helm chart to the dedicated namespace:
```bash
helm install snake-game /data/workspace/deployment/helm/snake-game/ --namespace snake-game-debug --create-namespace
```

## Deploying with ArgoCD

### 1. Ensure ArgoCD is installed in your cluster:
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Update the ArgoCD application manifest:
```bash
# Edit /data/workspace/deployment/argocd-application.yaml
# Update the repoURL to point to your actual Git repository
# Update the destination namespace as needed
```

### 3. Apply the ArgoCD application:
```bash
kubectl apply -f /data/workspace/deployment/argocd-application.yaml
```

The application will be deployed to the specified namespace as defined in the ArgoCD Application manifest.

## Verifying the Deployment

### 1. Check all pods are running in the selected environment namespace:
```bash
kubectl get pods -n snake-game-debug    # For debug environment
kubectl get pods -n snake-game-test     # For test environment
kubectl get pods -n snake-game-release  # For release environment
```

### 2. Check all services are available:
```bash
kubectl get services -n snake-game-debug    # For debug environment
kubectl get services -n snake-game-test     # For test environment
kubectl get services -n snake-game-release  # For release environment
```

### 3. View pod logs:
```bash
kubectl logs -l app=lobby -n snake-game-debug
kubectl logs -l app=matching -n snake-game-debug
kubectl logs -l app=room -n snake-game-debug
kubectl logs -l app=leaderboard -n snake-game-debug
kubectl logs -l app=game -n snake-game-debug
kubectl logs -l app=friends -n snake-game-debug
kubectl logs -l app=gateway -n snake-game-debug
```

## Accessing the Services

### 1. Get the gateway service external IP:
```bash
kubectl get service gateway -n snake-game-debug
```

### 2. If using LoadBalancer type, access the API at:
```
http://<EXTERNAL-IP>:8080/health
```

### 3. For ClusterIP services, use port forwarding:
```bash
kubectl port-forward service/gateway 8080:8080 -n snake-game-debug
kubectl port-forward service/lobby 50051:50051 -n snake-game-debug
kubectl port-forward service/matching 50052:50052 -n snake-game-debug
kubectl port-forward service/room 50053:50053 -n snake-game-debug
kubectl port-forward service/leaderboard 50054:50054 -n snake-game-debug
kubectl port-forward service/game 50055:50055 -n snake-game-debug
kubectl port-forward service/friends 50056:50056 -n snake-game-debug
```

## Troubleshooting

### 1. Check if MongoDB is accessible:
```bash
kubectl exec -it $(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}' -n snake-game-debug) -- mongosh --eval "db.runCommand('ping')"
```

### 2. Check service connectivity:
```bash
# From inside a pod, test connectivity to other services
kubectl run debug --image=curlimages/curl -it --rm -n snake-game-debug -- sh
# Then test connections, e.g.:
curl -v lobby:50051
```

### 3. Review application logs for connection errors:
```bash
kubectl logs -l app=lobby -n snake-game-debug | grep -i error
kubectl logs -l app=matching -n snake-game-debug | grep -i error
```

## Scaling Services

### 1. Scale individual services based on load:
```bash
kubectl scale deployment lobby --replicas=3 -n snake-game-debug
kubectl scale deployment matching --replicas=3 -n snake-game-debug
kubectl scale deployment gateway --replicas=2 -n snake-game-debug
```

### 2. Use Horizontal Pod Autoscaler for automatic scaling:
```bash
kubectl autoscale deployment lobby --cpu-percent=70 --min=1 --max=10 -n snake-game-debug
```

## Cleanup

### To remove all deployed resources for an environment:
```bash
kubectl delete namespace snake-game-debug    # For debug environment
kubectl delete namespace snake-game-test     # For test environment
kubectl delete namespace snake-game-release  # For release environment
```

Or to remove individual resources:
```bash
kubectl delete -f /data/workspace/deployment/gateway/gateway-deployment.yaml -n snake-game-debug
kubectl delete -f /data/workspace/deployment/friends/friends-deployment.yaml -n snake-game-debug
kubectl delete -f /data/workspace/deployment/game/game-deployment.yaml -n snake-game-debug
kubectl delete -f /data/workspace/deployment/leaderboard/leaderboard-deployment.yaml -n snake-game-debug
kubectl delete -f /data/workspace/deployment/room/room-deployment.yaml -n snake-game-debug
kubectl delete -f /data/workspace/deployment/matching/matching-deployment.yaml -n snake-game-debug
kubectl delete -f /data/workspace/deployment/lobby/lobby-deployment.yaml -n snake-game-debug
kubectl delete -f /data/workspace/deployment/mongodb/mongodb-deployment.yaml -n snake-game-debug
```