#!/usr/bin/env bash
# 部署到 namespace: helm-test（使用 envs/test 配置）
set -e
cd "$(dirname "$0")"
helm dependency update snake-game
helm upgrade --install snake-game-test ./snake-game \
  -n helm-test \
  -f envs/test/values.yaml \
  --create-namespace
