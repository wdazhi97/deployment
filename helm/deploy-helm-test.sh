#!/usr/bin/env bash
# 部署到 namespace: helm-test（按新结构：env/test/manifest/<服务名>/base + overlay）
set -e
cd "$(dirname "$0")"
for svc in mongodb lobby matching room leaderboard game friends gateway frontend; do
  helm upgrade --install "$svc" "env/test/manifest/$svc/base" \
    -n helm-test \
    -f "env/test/manifest/$svc/overlay/values.yaml" \
    --create-namespace
done
