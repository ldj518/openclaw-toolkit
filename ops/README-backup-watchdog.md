# OpenClaw 低内存备份 + 守护方案（2GB VPS）

## 目标
- 自动备份 workspace 历史（本地 bare 仓库，避免误删）
- 每日快照 tag（保留 30 天）
- 网关异常自动拉起
- **仅在明确配置错误时**才回滚配置

## 文件
- `setup-backup.sh`：初始化 bare 仓库 remote
- `backup-workspace.sh`：自动 commit/push + daily tag + 清理旧 tag
- `watchdog-gateway.sh`：健康检查 + 重启 + 条件回滚
- `install-cron.sh`：安装 cron（30 分钟备份，5 分钟守护）

## 一次性初始化
```bash
cd ~/.openclaw/workspace
chmod +x ops/*.sh
./ops/setup-backup.sh
./ops/install-cron.sh
```

## 恢复 workspace 历史（示例）
```bash
# 查看快照
cd ~/.openclaw/workspace
git fetch backup-local --tags
git tag -l 'daily-*' | tail

# 回到某个每日快照（先新建分支）
git checkout -b restore-2026-02-10 daily-2026-02-10
```

## 安全边界建议
- **不要**把 `~/.openclaw/openclaw.json`（含 token/key）直接推公网 GitHub。
- 如需异地备份，请做脱敏副本（模板）再推送。
- watchdog 默认策略：优先重启，不轻易回滚。
