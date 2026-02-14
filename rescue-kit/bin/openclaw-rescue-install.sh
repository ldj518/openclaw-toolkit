#!/usr/bin/env bash
set -euo pipefail

echo "== OpenClaw 一键救援安装（低内存）=="

echo "[1/8] 清理旧 Node/npm（忽略失败）"
dnf remove -y nodejs npm || true
rm -rf /usr/local/bin/node /usr/local/bin/npm /usr/local/lib/node_modules || true

echo "[2/8] 禁用系统 Node 流"
dnf module reset nodejs -y || true
dnf module disable nodejs -y || true

echo "[3/8] 配置 NodeSource 24"
curl -sL https://rpm.nodesource.com/setup_24.x | bash -

echo "[4/8] 安装 Node 与构建工具"
dnf install -y nodejs cmake gcc-c++ make || true
dnf groupinstall -y "Development Tools" || true

echo "[5/8] 确保 4G swap"
swapoff -a || true
if [[ ! -f /swapfile ]]; then
  dd if=/dev/zero of=/swapfile bs=1M count=4096
fi
chmod 600 /swapfile
mkswap /swapfile >/dev/null 2>&1 || true
swapon /swapfile || true
grep -q '^/swapfile ' /etc/fstab || echo '/swapfile swap swap defaults 0 0' >> /etc/fstab

echo "[6/8] 安装 OpenClaw（低内存参数）"
export NODE_OPTIONS="--max-old-space-size=1024"
npm install -g openclaw@latest --no-fund --no-audit --maxsockets 1 --loglevel info

echo "[7/8] 安装并启动 gateway"
openclaw gateway install
openclaw gateway start

echo "[8/8] 三联验收"
openclaw --version
openclaw gateway status
systemctl --user is-enabled openclaw-gateway.service
systemctl --user is-active openclaw-gateway.service

echo "[ok] 救援安装完成"
