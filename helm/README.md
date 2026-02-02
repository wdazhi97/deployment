# Snake Game Helm 部署

按「每服务一 Chart + 环境分目录」组织：各服务独立 Chart，Umbrella Chart 组合，不同环境使用不同目录的 values。

## 目录结构

```
helm/
├── README.md
├── deploy-helm-debug.sh      # 部署到 helm-debug
├── deploy-helm-test.sh       # 部署到 helm-test
├── deploy-helm-release.sh    # 部署到 helm-release
│
├── charts/                   # 各服务独立 Chart（可单独安装或复用）
│   ├── mongodb/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   ├── lobby/
│   ├── matching/
│   ├── room/
│   ├── leaderboard/
│   ├── game/
│   ├── friends/
│   ├── gateway/
│   └── frontend/
│
├── snake-game/               # Umbrella Chart（仅依赖 + values 透传，无业务模板）
│   ├── Chart.yaml            # dependencies 指向 charts/*
│   ├── values.yaml           # 默认透传，环境差异不写在这里
│   └── templates/
│       └── NOTES.txt
│
└── envs/                     # 按环境分目录，每环境仅保留 values
    ├── debug/
    │   └── values.yaml       # helm-debug 环境
    ├── test/
    │   └── values.yaml       # helm-test 环境
    └── release/
        └── values.yaml       # helm-release 环境
```

## 设计说明

| 层级 | 作用 |
|------|------|
| **charts/\*** | 每个服务一个 Chart，配置与模板只关心本服务，可单独 `helm install` 或作为依赖 |
| **snake-game/** | Umbrella Chart，只声明依赖各子 Chart，不堆砌业务配置；values 仅做透传与少量覆盖 |
| **envs/debug、test、release** | 不同环境不同目录，每目录仅一份 values，部署时指定 `-f envs/<env>/values.yaml` |

## 部署到各 Namespace

在 `helm/` 目录下执行（需先 `helm dependency update snake-game`）：

```bash
# helm-debug
./deploy-helm-debug.sh
# 或
helm dependency update snake-game
helm install snake-game-debug ./snake-game -n helm-debug -f envs/debug/values.yaml --create-namespace

# helm-test
./deploy-helm-test.sh

# helm-release
./deploy-helm-release.sh
```

## 常用操作

```bash
# 首次或更新子 Chart 后，更新依赖
helm dependency update snake-game

# 预览渲染（不安装）
helm template snake-game-debug ./snake-game -n helm-debug -f envs/debug/values.yaml

# 升级
helm upgrade snake-game-debug ./snake-game -n helm-debug -f envs/debug/values.yaml

# 卸载
helm uninstall snake-game-debug -n helm-debug
```

## 单独安装某个服务

例如只装 lobby（需集群内已有 mongodb 服务）：

```bash
helm install lobby ./charts/lobby -n helm-debug -f envs/debug/values.yaml
# 或覆盖 mongodbUri
helm install lobby ./charts/lobby -n helm-debug --set mongodbUri="mongodb://user:pass@mongodb:27017"
```

## 环境差异如何写

- **公共默认**：写在对应 `charts/<service>/values.yaml`。
- **某环境覆盖**：写在 `envs/<env>/values.yaml`，例如：

```yaml
# envs/debug/values.yaml
global:
  environment: debug
mongodb:
  replicas: 1
lobby:
  replicas: 1
gateway:
  environment: debug   # 与 global.environment 一致时可省略
```

这样配置不会堆砌在 Umbrella 里，各环境、各服务职责清晰。
