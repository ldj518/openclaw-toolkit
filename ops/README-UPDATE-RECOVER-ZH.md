# 升级失败（OOM/Killed）一键恢复方案

## 1) 安全升级（推荐）
```bash
bash /root/.openclaw/workspace/ops/update-safe.sh
```
- 自动低内存参数
- 升级前自动备份
- 升级后自动验收
- 验收失败自动回滚到升级前版本

## 2) 如果升级中断/被 kill，直接一键恢复
```bash
bash /root/.openclaw/workspace/ops/update-recover.sh
```

## 3) 手工兜底（极端情况）
```bash
export NODE_OPTIONS="--max-old-space-size=1024"
npm install -g openclaw@2026.2.12 --no-fund --no-audit --maxsockets 1
systemctl --user restart openclaw-gateway.service
openclaw gateway status
```

## 关键文件
- 状态文件: `/root/.openclaw/update-safe.state`
- 日志文件: `/root/.openclaw/update-safe.log`
