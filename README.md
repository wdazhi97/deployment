# Snake Game Microservices - Clean Architecture Deployment

This repository contains deployment configurations for the Snake Game microservices architecture with Clean Architecture implementation using ArgoCD for GitOps continuous delivery.

## Architecture Overview

The Snake Game is composed of the following microservices with Clean Architecture:

1. **API Gateway** - Centralized entry point for all client requests (port 8080)
   - Clean Architecture layers: HTTP delivery, usecase, service registry
2. **Lobby Service** - User authentication and profile management (port 50051)
   - Clean Architecture layers: gRPC delivery, auth usecase, user repository
3. **Matching Service** - Player matching functionality (port 50052)
   - Clean Architecture layers: gRPC delivery, matching usecase, player repository
4. **Room Service** - Game room management and chat (port 50053)
   - Clean Architecture layers: gRPC delivery, room usecase, in-memory repository (stateful)
5. **Leaderboard Service** - Score tracking and ranking (port 50054)
   - Clean Architecture layers: gRPC delivery, leaderboard usecase, MongoDB repository
6. **Game Service** - Real-time game state management (port 50055)
   - Clean Architecture layers: gRPC delivery, game usecase, in-memory repository (stateful)
7. **Friends Service** - Social features and friend management (port 50056)
   - Clean Architecture layers: gRPC delivery, friends usecase, MongoDB repository
8. **MongoDB** - Data persistence layer

## Key Architecture Improvements

### 1. Clean Architecture Implementation
- **Presentation Layer** (Delivery): Handles communication protocols (gRPC/HTTP)
- **Business Layer** (UseCase): Contains core business logic
- **Data Layer** (Repository): Manages data persistence and retrieval
- **Domain Layer**: Contains business entities and rules

### 2. Service Classification
- **Stateful Services** (no database): Game, Room services (in-memory state management)
- **Stateless Services** (with database): Lobby, Leaderboard, Friends, Matching services
- **Game Result Flow**: Game service sends results to Leaderboard service upon game completion

### 3. Separated Proto Files
- Each service has its own proto file in `proto_new/` directory
- Common types defined in `common.proto`
- Better maintainability and reduced coupling

### 4. Multi-Environment Configuration
- **Directory Structure**: `env/{debug,test,release}/{base,overlay}`
- **Isolated Namespaces**: `snake-game-{debug,test,release}`
- **Configurable Resources**: Per-environment resource allocation
- **Different Logging Levels**: Appropriate for each environment

## Deployment Options

### Option 1: Using the Multi-Environment Deployment Script (Recommended)

Execute the provided multi-environment deployment script:

```bash
# Make the script executable
chmod +x deploy-env.sh

# Build images and deploy to debug environment
./deploy-env.sh all debug

# Build images and deploy to test environment
./deploy-env.sh all test

# Build images and deploy to release environment
./deploy-env.sh all release

# Or perform individual steps for specific environment
./deploy-env.sh build                    # Build Docker images
./deploy-env.sh deploy debug            # Deploy to debug environment
./deploy-env.sh deploy test             # Deploy to test environment
./deploy-env.sh deploy release          # Deploy to release environment
./deploy-env.sh verify debug            # Verify debug environment
```

### Option 2: Using the Legacy Deployment Script

For single environment deployment (legacy mode):

```bash
# Make the script executable
chmod +x deploy.sh

# Build images and deploy everything (to default snake-game namespace)
./deploy.sh all
```

### Option 3: Manual Deployment with Kubectl

Deploy services in dependency order:

```bash
# 1. Create dedicated namespace for your environment (example for debug)
kubectl create namespace snake-game-debug

# 2. Deploy MongoDB first
kubectl apply -f mongodb/mongodb-deployment.yaml -n snake-game-debug

# 3. Deploy stateless services
kubectl apply -f lobby/lobby-deployment.yaml -n snake-game-debug
kubectl apply -f matching/matching-deployment.yaml -n snake-game-debug
kubectl apply -f leaderboard/leaderboard-deployment.yaml -n snake-game-debug
kubectl apply -f friends/friends-deployment.yaml -n snake-game-debug

# 4. Deploy stateful services
kubectl apply -f room/room-deployment.yaml -n snake-game-debug
kubectl apply -f game/game-deployment.yaml -n snake-game-debug

# 5. Deploy gateway last
kubectl apply -f gateway/gateway-deployment.yaml -n snake-game-debug
```

### Option 4: Using Kustomize

Apply the kustomize configuration for a specific environment:

```bash
# Apply debug environment (default)
kubectl apply -k .

# Or apply specific environment
kubectl apply -k env/debug/overlay/
kubectl apply -k env/test/overlay/
kubectl apply -k env/release/overlay/
```

### Option 5: Using Helm

Install the Helm chart to a dedicated namespace:

```bash
# Install directly from local chart
helm install snake-game ./helm/snake-game/ --namespace snake-game-debug --create-namespace

# With custom values
helm install snake-game ./helm/snake-game/ --namespace snake-game-debug --create-namespace -f my-values.yaml
```

### Option 6: ArgoCD Application

Apply the ArgoCD application manifest:

```bash
kubectl apply -f argocd-application.yaml
```

This will deploy the application to the `snake-game` namespace. Make sure to update the `repoURL` field in the application manifest to point to your actual Git repository.

## Environment Configuration

We support three distinct environments:

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

## Configuration

### Environment Variables

All services require a MongoDB connection string. The default is:

```
MONGODB_URI=mongodb://mongodb:27017
```

### Customization

You can customize the deployment by modifying:
- The `values.yaml` file in the Helm chart
- Overlay configurations in the `env/` directory
- Individual service configurations as needed

## Services Exposure

- **API Gateway**: Exposed via LoadBalancer service on port 8080
- **Internal services**: Accessible only within the cluster via ClusterIP services

## Health Checks

- Gateway service has HTTP health checks on `/health` endpoint
- All gRPC services have TCP socket health checks

## Persistence

MongoDB uses PersistentVolumeClaims for data persistence. Stateful services (Game, Room) maintain state in-memory and do not persist data directly. You can configure storage class and size in the values file.

## Scaling

Individual services can be scaled independently based on demand:
- Stateless services can be scaled horizontally easily
- Stateful services (Game, Room) require careful scaling considerations
- Configure replica counts per environment in the overlay configurations

## Service Communication

- Services communicate via gRPC
- Game service notifies Leaderboard service of game results
- Gateway acts as API aggregator and router

## Monitoring and Logging

Services can be enhanced with monitoring and logging sidecars as needed. Standard Kubernetes logging and monitoring practices apply.