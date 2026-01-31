# Snake Game Microservices - Environment Configuration

This directory contains environment-specific configurations for the Snake Game microservices using Kustomize's base and overlay pattern.

## Directory Structure

```
env/
├── debug/                           # Development/Debug environment
│   ├── snake-game-namespace.yaml    # Debug namespace definition
│   ├── snake-game-networkpolicy.yaml # Debug network policy
│   ├── base/                        # Base configuration for debug
│   │   ├── kustomization.yaml
│   │   ├── lobby/                   # Lobby service files
│   │   ├── matching/                # Matching service files
│   │   ├── room/                    # Room service files
│   │   ├── leaderboard/             # Leaderboard service files
│   │   ├── game/                    # Game service files
│   │   ├── friends/                 # Friends service files
│   │   ├── gateway/                 # Gateway service files
│   │   └── mongodb/                 # MongoDB service files
│   └── overlay/                     # Debug-specific overrides
│       ├── kustomization.yaml
│       ├── lobby/values.yaml        # Debug-specific lobby config
│       ├── matching/values.yaml     # Debug-specific matching config
│       ├── room/values.yaml         # Debug-specific room config
│       ├── leaderboard/values.yaml  # Debug-specific leaderboard config
│       ├── game/values.yaml         # Debug-specific game config
│       ├── friends/values.yaml      # Debug-specific friends config
│       └── gateway/values.yaml      # Debug-specific gateway config
├── test/                            # Testing environment
│   ├── snake-game-namespace.yaml    # Test namespace definition
│   ├── snake-game-networkpolicy.yaml # Test network policy
│   ├── base/                        # Base configuration for test
│   │   ├── kustomization.yaml
│   │   ├── lobby/                   # Lobby service files
│   │   ├── matching/                # Matching service files
│   │   ├── room/                    # Room service files
│   │   ├── leaderboard/             # Leaderboard service files
│   │   ├── game/                    # Game service files
│   │   ├── friends/                 # Friends service files
│   │   ├── gateway/                 # Gateway service files
│   │   └── mongodb/                 # MongoDB service files
│   └── overlay/                     # Test-specific overrides
│       ├── kustomization.yaml
│       ├── lobby/values.yaml        # Test-specific lobby config
│       ├── matching/values.yaml     # Test-specific matching config
│       ├── room/values.yaml         # Test-specific room config
│       ├── leaderboard/values.yaml  # Test-specific leaderboard config
│       ├── game/values.yaml         # Test-specific game config
│       ├── friends/values.yaml      # Test-specific friends config
│       └── gateway/values.yaml      # Test-specific gateway config
└── release/                         # Production environment
    ├── snake-game-namespace.yaml    # Release namespace definition
    ├── snake-game-networkpolicy.yaml # Release network policy
    ├── base/                        # Base configuration for release
    │   ├── kustomization.yaml
    │   ├── lobby/                   # Lobby service files
    │   ├── matching/                # Matching service files
    │   ├── room/                    # Room service files
    │   ├── leaderboard/             # Leaderboard service files
    │   ├── game/                    # Game service files
    │   ├── friends/                 # Friends service files
    │   ├── gateway/                 # Gateway service files
    │   └── mongodb/                 # MongoDB service files
    └── overlay/                     # Release-specific overrides
        ├── kustomization.yaml
        ├── lobby/values.yaml        # Release-specific lobby config
        ├── matching/values.yaml     # Release-specific matching config
        ├── room/values.yaml         # Release-specific room config
        ├── leaderboard/values.yaml  # Release-specific leaderboard config
        ├── game/values.yaml         # Release-specific game config
        ├── friends/values.yaml      # Release-specific friends config
        └── gateway/values.yaml      # Release-specific gateway config
```

## Environments

### 1. Debug Environment (`debug`)
- **Namespace**: `snake-game-debug`
- **Replica Counts**: Minimal (1-1 for most services)
- **Logging Level**: `debug`
- **Resources**: Lower resource limits for development
- **Purpose**: Development and debugging

### 2. Test Environment (`test`)
- **Namespace**: `snake-game-test`
- **Replica Counts**: Moderate (2-2 for most services)
- **Logging Level**: `info`
- **Resources**: Medium resource allocation
- **Purpose**: Integration testing and QA

### 3. Release Environment (`release`)
- **Namespace**: `snake-game-release`
- **Replica Counts**: Higher availability (3+ replicas)
- **Logging Level**: `warn`
- **Resources**: Full production resource allocation
- **Purpose**: Production deployment

## Usage

### Deploy to Specific Environment

Using the deployment script:
```bash
# Deploy to debug environment
./deploy-env.sh deploy debug

# Deploy to test environment
./deploy-env.sh deploy test

# Deploy to release environment
./deploy-env.sh deploy release
```

Or directly with kubectl and kustomize:
```bash
# Deploy debug environment
kubectl apply -k env/debug/overlay/

# Deploy test environment
kubectl apply -k env/test/overlay/

# Deploy release environment
kubectl apply -k env/release/overlay/
```

### Verify Deployment

```bash
# Verify debug environment
./deploy-env.sh verify debug

# Verify test environment
./deploy-env.sh verify test

# Verify release environment
./deploy-env.sh verify release
```

## Configuration Differences

Each environment has specific configurations managed through values.yaml files in the overlay directories:

- **Replica Counts**: Different numbers based on environment requirements
- **Resource Limits**: Appropriate for each environment's needs
- **Logging Levels**: Appropriate verbosity for each environment
- **Namespaces**: Isolated for each environment

## Best Practices

1. **Always test in lower environments first** before deploying to production
2. **Use debug environment** for development and troubleshooting
3. **Use test environment** for integration testing
4. **Use release environment** only for production deployments
5. **Keep environment-specific secrets separate** using Kubernetes secrets

## Rollback Strategy

If issues occur in an environment, you can rollback using:
```bash
kubectl rollout undo deployment/<deployment-name> -n <environment-namespace>
```