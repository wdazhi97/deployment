#!/usr/bin/env bash
# 部署到 namespace: helm-release（按新结构：env/release/manifest/<服务名>/base + overlay）
set -e
cd "$(dirname "$0")"
for svc in mongodb lobby matching room leaderboard game friends gateway frontend; do
  helm upgrade --install "$svc" "env/release/manifest/$svc/base" \
    -n helm-release \
    -f "env/release/manifest/$svc/overlay/values.yaml" \
    --create-namespace
done
