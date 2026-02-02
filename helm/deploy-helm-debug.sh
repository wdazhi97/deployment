#!/usr/bin/env bash
# 部署到 namespace: helm-debug（按新结构：env/debug/manifest/<服务名>/base + overlay）
set -e
cd "$(dirname "$0")"
for svc in mongodb lobby matching room leaderboard game friends gateway frontend; do
  helm upgrade --install "$svc" "env/debug/manifest/$svc/base" \
    -n helm-debug \
    -f "env/debug/manifest/$svc/overlay/values.yaml" \
    --create-namespace
done
