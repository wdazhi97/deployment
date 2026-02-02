# Helm 部署目录说明

按「环境 → deploy / manifest → 服务」组织：不同环境不同目录，每个服务的 manifest 内直接包含完整 Chart（base = 完整 Chart，overlay = 环境 values）。

## 目录结构

```
helm/
└── env/
    ├── debug/
    │   ├── deploy/                  # helmfiles 指导部署
    │   │   ├── mongodb/
    │   │   │   └── helmfile.yaml
    │   │   ├── lobby/
    │   │   │   └── helmfile.yaml
    │   │   └── ... (其余服务)
    │   └── manifest/                # 每个服务含完整 Chart
    │       ├── mongodb/
    │       │   ├── base/            # 完整 Chart（Chart.yaml + values.yaml + templates/）
    │       │   │   ├── Chart.yaml
    │       │   │   ├── values.yaml
    │       │   │   └── templates/
    │       │   └── overlay/         # 环境 overlay values
    │       │       └── values.yaml
    │       ├── lobby/
    │       │   ├── base/
    │       │   └── overlay/
    │       └── ... (其余服务)
    ├── test/
    │   ├── deploy/
    │   └── manifest/
    └── release/
        ├── deploy/
        └── manifest/
```

## 说明

| 路径 | 含义 |
|------|------|
| **helm/env/.../deploy/(服务名)/** | helmfiles 指导部署，指向同环境下 manifest 的 base + overlay |
| **helm/env/.../manifest/(服务名)/base/** | **完整 Chart**：Chart.yaml、values.yaml、templates/，无外部依赖 |
| **helm/env/.../manifest/(服务名)/overlay/** | 环境 overlay：values.yaml 覆盖 base，用于该环境差异化配置 |

每个环境的 manifest 里都放完整 chart，base 不再依赖共享 charts 目录。

## 部署方式

### 单服务（Helm）

```bash
cd helm/env/debug
helm upgrade --install mongodb manifest/mongodb/base -n helm-debug \
  -f manifest/mongodb/overlay/values.yaml --create-namespace
```

### 使用 Helmfile（若已安装 helmfile）

```bash
cd helm/env/debug/deploy/mongodb
helmfile sync
```

### ArgoCD

按服务建 Application（或 ApplicationSet）：

- **path**: `helm/env/debug/manifest/<服务名>/base`
- **valueFiles**: `../overlay/values.yaml`
- **releaseName**: `<服务名>`
- **namespace**: `helm-debug`（或 test/release 对应 helm-test、helm-release）

## 环境与 Namespace

| 环境 | Namespace |
|------|-----------|
| debug | helm-debug |
| test | helm-test |
| release | helm-release |
