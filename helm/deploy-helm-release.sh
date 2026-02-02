#!/usr/bin/env bash
# 部署到 namespace: helm-release（使用 envs/release 配置）
set -e
cd "$(dirname "$0")"
helm dependency update snake-game
helm upgrade --install snake-game-release ./snake-game \
  -n helm-release \
  -f envs/release/values.yaml \
  --create-namespace
