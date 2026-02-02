#!/usr/bin/env bash
# 部署到 namespace: helm-debug（使用 envs/debug 配置）
set -e
cd "$(dirname "$0")"
helm dependency update snake-game
helm upgrade --install snake-game-debug ./snake-game \
  -n helm-debug \
  -f envs/debug/values.yaml \
  --create-namespace
