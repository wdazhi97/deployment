# Kubernetes + Kustomize + ArgoCD 部署问题笔记

本文档记录了在部署 Snake Game 微服务项目到 Kubernetes 集群过程中遇到的各种问题及其解决方案。

---

## 目录

1. [Kustomize 配置问题](#1-kustomize-配置问题)
   - [1.1 重复 Service 定义](#11-重复-service-定义)
   - [1.2 废弃语法警告](#12-废弃语法警告)
   - [1.3 Base/Overlay 结构理解](#13-baseoverlay-结构理解)
2. [ArgoCD 同步问题](#2-argocd-同步问题)
   - [2.1 仓库 URL 格式不匹配](#21-仓库-url-格式不匹配)
   - [2.2 路径不存在错误](#22-路径不存在错误)
   - [2.3 targetRevision 缓存问题](#23-targetrevision-缓存问题)
   - [2.4 Selector 不可变错误](#24-selector-不可变错误)
3. [Kubernetes 资源调度问题](#3-kubernetes-资源调度问题)
   - [3.1 CPU 资源不足](#31-cpu-资源不足)
   - [3.2 资源配置无效 (requests > limits)](#32-资源配置无效-requests--limits)
4. [容器镜像问题](#4-容器镜像问题)
   - [4.1 ErrImageNeverPull 错误](#41-errimagenerverpull-错误)
   - [4.2 Docker vs Containerd 镜像存储](#42-docker-vs-containerd-镜像存储)
5. [Go 编译与运行时问题](#5-go-编译与运行时问题)
   - [5.1 glibc vs musl 不兼容](#51-glibc-vs-musl-不兼容)
   - [5.2 二进制文件路径错误](#52-二进制文件路径错误)
6. [存储持久化问题](#6-存储持久化问题)
   - [6.1 MongoDB 数据丢失](#61-mongodb-数据丢失)
   - [6.2 PVC 状态异常](#62-pvc-状态异常)
7. [YAML 语法问题](#7-yaml-语法问题)
   - [7.1 多文档分隔符缺失](#71-多文档分隔符缺失)

---

## 1. Kustomize 配置问题

### 1.1 重复 Service 定义

**错误信息：**
```
error: accumulating resources: accumulation err='merging resources from 
'mongodb/mongodb-service.yaml': may not add resource with an already 
registered id: Service.v1.[noGrp]/mongodb.[noNs]'
```

**问题原因：**
- `*-deployment.yaml` 文件中已经包含了 Service 定义（用 `---` 分隔）
- `kustomization.yaml` 又单独引用了 `*-service.yaml` 文件
- 导致同一个 Service 被定义了两次

**解决方案：**
```yaml
# 删除 kustomization.yaml 中的 service 引用
resources:
- mongodb/deployment.yaml      # 包含 Deployment + Service
# - mongodb/mongodb-service.yaml  # 删除这行

# 删除独立的 service 文件
rm mongodb/mongodb-service.yaml
```

**最佳实践：**
- 将同一服务的 Deployment 和 Service 放在同一个文件中，用 `---` 分隔
- 或者完全分离，但不要两种方式混用

---

### 1.2 废弃语法警告

**问题：Kustomize 的 `bases` 和 `commonLabels` 已废弃**

#### 1.2.1 `bases` 废弃

**旧语法：**
```yaml
# ❌ 废弃
bases:
- ../base
```

**新语法：**
```yaml
# ✅ 推荐
resources:
- ../base
```

#### 1.2.2 `commonLabels` 废弃

**旧语法：**
```yaml
# ❌ 废弃 - 会修改 selector（导致不可变错误）
commonLabels:
  environment: debug
```

**新语法：**
```yaml
# ✅ 推荐 - includeSelectors: false 避免修改 selector
labels:
- pairs:
    environment: debug
  includeSelectors: false
```

**重要说明：**
- `commonLabels` 会自动将标签添加到 `spec.selector.matchLabels`
- Kubernetes 不允许修改 Deployment 的 selector
- 使用新语法 `labels` 配合 `includeSelectors: false` 可以只添加 metadata labels

---

### 1.3 Base/Overlay 结构理解

**概念：**
```
env/debug/
├── base/                    # 基础配置
│   ├── kustomization.yaml   # 定义资源列表、namespace、labels
│   └── */deployment.yaml    # 具体资源定义
└── overlay/                 # 环境特定配置
    ├── kustomization.yaml   # 引用 base，定义 patches
    └── */patch.yaml         # 补丁文件
```

**工作原理：**
1. Overlay 的 `kustomization.yaml` 通过 `resources: [../base]` 引用 Base
2. Patches 使用 Strategic Merge Patch 策略合并到 Base 资源
3. 最终生成的 YAML 是 Base + Overlay 的合并结果

**部署命令：**
```bash
# 只部署 base（不应用 overlay）
kubectl apply -k env/debug/base

# 部署 overlay（包含 base + patches）
kubectl apply -k env/debug/overlay
```

---

## 2. ArgoCD 同步问题

### 2.1 仓库 URL 格式不匹配

**错误现象：**
ArgoCD 无法拉取仓库，显示认证失败

**问题原因：**
- ArgoCD 仓库 Secret 配置的是 SSH URL：`git@github.com:user/repo.git`
- Application 定义使用的是 HTTPS URL：`https://github.com/user/repo.git`
- 两者格式不匹配导致认证失败

**解决方案：**
```yaml
# Application 定义
spec:
  source:
    # ❌ 错误 - 与 Secret 格式不匹配
    repoURL: https://github.com/user/repo.git
    
    # ✅ 正确 - 与 Secret 格式一致
    repoURL: git@github.com:user/repo.git
```

**验证方法：**
```bash
# 查看 ArgoCD 已配置的仓库
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository -o yaml
```

---

### 2.2 路径不存在错误

**错误信息：**
```
Manifest generation error: env/release/overlay: app path does not exist
```

**可能原因：**
1. Git 仓库中确实没有该路径
2. ArgoCD 使用了旧的 Git 提交（缓存）
3. 本地修改未 push 到远程仓库

**排查步骤：**
```bash
# 1. 检查本地是否有该路径
ls -la env/release/overlay/

# 2. 检查远程仓库是否有该路径
git ls-tree -r HEAD --name-only | grep "env/release/overlay"

# 3. 检查是否有未推送的提交
git status
git log origin/master..HEAD
```

**解决方案：**
```bash
# 确保本地修改已推送
git add -A && git commit -m "add files" && git push origin master

# 重启 ArgoCD repo-server 清除缓存
kubectl delete pods -n argocd -l app.kubernetes.io/name=argocd-repo-server

# 强制刷新 Application
kubectl patch application <app-name> -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

---

### 2.3 targetRevision 缓存问题

**问题描述：**
ArgoCD 显示同步的是旧的 commit，而不是最新的

**问题原因：**
`targetRevision: HEAD` 在某些情况下会被缓存，不会自动更新

**解决方案：**
```yaml
spec:
  source:
    # ❌ 可能被缓存
    targetRevision: HEAD
    
    # ✅ 明确指定分支名
    targetRevision: master
```

**强制刷新：**
```bash
# 重启 repo-server
kubectl delete pods -n argocd -l app.kubernetes.io/name=argocd-repo-server

# 等待 Pod 就绪后刷新
kubectl patch application <app-name> -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

---

### 2.4 Selector 不可变错误

**错误信息：**
```
spec.selector: Invalid value: field is immutable
```

**问题原因：**
- Kubernetes 不允许修改已存在 Deployment 的 `spec.selector.matchLabels`
- 当从 `commonLabels` 切换到 `labels`（或反向），会尝试修改 selector

**解决方案：**
```bash
# 删除受影响的 Deployments，让 ArgoCD 重新创建
kubectl delete deployments --all -n snake-game-debug

# 等待 ArgoCD 自动同步重建
# 或手动触发同步
kubectl patch application <app-name> -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

**预防措施：**
- 使用 `labels` + `includeSelectors: false` 避免修改 selector
- 规划好标签策略，尽量不在生产环境变更

---

## 3. Kubernetes 资源调度问题

### 3.1 CPU 资源不足

**错误信息：**
```
Warning  FailedScheduling  0/1 nodes are available: 1 Insufficient cpu
```

**问题原因：**
- 单节点集群 CPU 资源有限
- 多个 Pod 的 CPU requests 总和超过了可用 CPU

**排查命令：**
```bash
# 查看节点资源使用情况
kubectl describe node | grep -A 10 "Allocated resources"

# 查看所有 Pod 的资源请求
kubectl get pods --all-namespaces -o custom-columns=\
"NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU:.spec.containers[*].resources.requests.cpu"
```

**解决方案：**
```yaml
# 降低资源请求
resources:
  requests:
    cpu: "10m"      # 原来是 100m 或更高
    memory: "64Mi"
  limits:
    cpu: "100m"
    memory: "128Mi"
```

**其他方案：**
- 减少副本数 (`replicas: 1`)
- 删除不需要的环境（如暂时删除 test/release）
- 扩展集群节点

---

### 3.2 资源配置无效 (requests > limits)

**错误信息：**
```
Invalid value: "250m": must be less than or equal to cpu limit of 10m
Invalid value: "256Mi": must be less than or equal to memory limit of 64Mi
```

**问题原因：**
资源配置违反规则：`requests` 必须 ≤ `limits`

**错误示例：**
```yaml
# ❌ 错误 - requests > limits
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "10m"       # 小于 requests
    memory: "64Mi"   # 小于 requests
```

**正确示例：**
```yaml
# ✅ 正确 - requests ≤ limits
resources:
  requests:
    cpu: "10m"
    memory: "64Mi"
  limits:
    cpu: "100m"
    memory: "128Mi"
```

**概念说明：**
- `requests`: 调度时保证的最小资源量
- `limits`: 容器可使用的最大资源量
- requests 用于调度决策，limits 用于运行时限制

---

## 4. 容器镜像问题

### 4.1 ErrImageNeverPull 错误

**错误信息：**
```
Container image "snake-game-friends:latest" is not present with pull policy of Never
```

**问题原因：**
- `imagePullPolicy: Never` 表示不从远程拉取镜像
- 但 Kubernetes 节点上找不到该镜像

**解决方案：**

1. **如果使用远程镜像仓库：**
```yaml
imagePullPolicy: Always  # 或 IfNotPresent
```

2. **如果使用本地镜像（见 4.2）：**
需要将镜像导入到 Kubernetes 使用的容器运行时

---

### 4.2 Docker vs Containerd 镜像存储

**问题描述：**
`docker images` 显示镜像存在，但 Kubernetes 找不到

**问题原因：**
- Docker 和 Containerd（k3s 默认运行时）使用**独立的镜像存储**
- `docker build` 构建的镜像存储在 Docker 中
- k3s 使用 Containerd，需要单独导入

**解决方案：**
```bash
# 方法1：从 Docker 导出并导入到 k3s
docker save snake-game-lobby:latest | k3s ctr images import -

# 方法2：批量导入所有镜像
for img in lobby matching room leaderboard game friends gateway; do
  docker save snake-game-$img:latest | k3s ctr images import -
done

# 验证镜像已导入
k3s ctr images list | grep snake-game
```

**其他容器运行时导入方法：**
```bash
# minikube
minikube image load snake-game-lobby:latest

# kind
kind load docker-image snake-game-lobby:latest

# containerd (非 k3s)
ctr images import image.tar
```

---

## 5. Go 编译与运行时问题

### 5.1 glibc vs musl 不兼容

**错误信息：**
```
Error relocating /root/bin/friends_server: __vfprintf_chk: symbol not found
```

**问题原因：**
- Go 程序默认使用 CGO，会动态链接 glibc
- Alpine Linux 使用 musl libc（不是 glibc）
- glibc 编译的二进制无法在 musl 环境运行

**解决方案：**

**方法1：静态链接（推荐）**
```bash
# 禁用 CGO，启用静态链接
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -ldflags="-s -w" \
  -o bin/server main.go
```

参数说明：
- `CGO_ENABLED=0`: 禁用 CGO，强制纯 Go 编译
- `GOOS=linux GOARCH=amd64`: 交叉编译目标平台
- `-ldflags="-s -w"`: 去除符号表和调试信息，减小二进制体积

**方法2：使用 glibc 基础镜像**
```dockerfile
# 使用 glibc 基础镜像替代 Alpine
FROM debian:bullseye-slim
# 或
FROM ubuntu:22.04
```

**验证二进制类型：**
```bash
# 检查是否静态链接
file bin/server
# 应显示: statically linked

# 检查动态库依赖
ldd bin/server
# 静态链接应显示: not a dynamic executable
```

---

### 5.2 二进制文件路径错误

**错误信息：**
```
exec ./bin/lobby_server: no such file or directory
```

**问题原因：**
- Dockerfile 中将二进制复制到 `/root/bin/`
- Deployment 配置的 command 使用相对路径 `./bin/`
- 容器启动时工作目录不是 `/root`

**排查方法：**
```bash
# 检查镜像中的文件位置
docker run --rm snake-game-lobby:latest ls -la /root/bin/
```

**解决方案：**
```yaml
# ❌ 错误 - 相对路径
command: ["./bin/lobby_server"]

# ✅ 正确 - 绝对路径
command: ["/root/bin/lobby_server"]
```

**最佳实践：**
- 在 Kubernetes 配置中始终使用绝对路径
- 或在 Dockerfile 中设置 `WORKDIR` 确保相对路径可用

---

## 6. 存储持久化问题

### 6.1 MongoDB 数据丢失

**问题描述：**
Pod 重启后 MongoDB 数据丢失

**问题原因：**
使用 `emptyDir` 作为存储卷，Pod 删除时数据会丢失

```yaml
# ❌ 非持久化 - Pod 删除后数据丢失
volumes:
- name: mongodb-storage
  emptyDir: {}
```

**解决方案：**
```yaml
# 1. 创建 PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
# 2. 在 Deployment 中使用 PVC
volumes:
- name: mongodb-storage
  persistentVolumeClaim:
    claimName: mongodb-pvc
```

---

### 6.2 PVC 状态异常

**问题：PVC 显示 Pending 或 Progressing**

**排查步骤：**
```bash
# 查看 PVC 状态
kubectl get pvc -n snake-game-debug

# 查看 PVC 详情
kubectl describe pvc mongodb-pvc -n snake-game-debug

# 查看 StorageClass
kubectl get storageclass
```

**常见原因与解决：**

1. **没有可用的 StorageClass**
```bash
# 检查是否有默认 StorageClass
kubectl get storageclass

# k3s 默认有 local-path StorageClass
```

2. **PVC 未被 Pod 使用（WaitForFirstConsumer）**
```yaml
# StorageClass 使用 WaitForFirstConsumer 模式
# PVC 会等到 Pod 调度时才绑定
volumeBindingMode: WaitForFirstConsumer
```

3. **Deployment 没有引用 PVC**
```yaml
# 确保 volumes 正确引用 PVC
volumes:
- name: mongodb-storage
  persistentVolumeClaim:
    claimName: mongodb-pvc  # 必须与 PVC 名称匹配
```

---

## 7. YAML 语法问题

### 7.1 多文档分隔符缺失

**错误信息：**
```
yaml: unmarshal errors: line 37: mapping key "apiVersion" already defined at line 1
```

**问题原因：**
同一文件中有多个 Kubernetes 资源，但缺少 `---` 分隔符

**错误示例：**
```yaml
# ❌ 缺少分隔符
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
spec:
  ...
apiVersion: v1        # 错误：没有 ---
kind: Service
...
```

**正确示例：**
```yaml
# ✅ 使用 --- 分隔多个资源
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
spec:
  ...
---                    # 分隔符
apiVersion: v1
kind: Service
metadata:
  name: mongodb
spec:
  ...
```

**验证 YAML 语法：**
```bash
# 使用 kubectl 验证
kubectl apply --dry-run=client -f deployment.yaml

# 使用 kustomize 验证
kubectl kustomize env/debug/overlay/ > /dev/null && echo "OK"
```

---

## 常用调试命令速查

```bash
# === Kubernetes 基础 ===
kubectl get pods -n <namespace>                    # 查看 Pod
kubectl describe pod <pod-name> -n <namespace>     # Pod 详情
kubectl logs <pod-name> -n <namespace>             # 查看日志
kubectl get events -n <namespace> --sort-by='.lastTimestamp'  # 事件

# === ArgoCD ===
kubectl get applications -n argocd                 # 查看应用
kubectl get application <name> -n argocd -o yaml   # 应用详情
kubectl delete pods -n argocd -l app.kubernetes.io/name=argocd-repo-server  # 清缓存

# === Kustomize ===
kubectl kustomize <path>                           # 预览生成的 YAML
kubectl apply -k <path> --dry-run=client           # 干跑测试

# === 镜像 ===
docker images | grep snake-game                    # Docker 镜像
k3s ctr images list | grep snake-game              # k3s 镜像
docker save <image> | k3s ctr images import -      # 导入镜像

# === 资源 ===
kubectl describe node | grep -A 10 "Allocated"     # 节点资源使用
kubectl top pods -n <namespace>                    # Pod 资源使用
```

---

## 文件结构最佳实践

```
deployment/
├── argocd/
│   ├── debug-application.yaml
│   ├── test-application.yaml
│   └── release-application.yaml
└── env/
    └── {debug,test,release}/
        ├── base/
        │   ├── kustomization.yaml
        │   ├── namespace.yaml
        │   └── {service}/
        │       └── deployment.yaml    # Deployment + Service
        └── overlay/
            ├── kustomization.yaml
            └── {service}/
                └── patch.yaml         # 环境特定配置
```

---

*文档生成时间：2026-01-31*
*项目：Snake Game 微服务部署*
