# 灾难恢复（OpenClaw 挂了也能用）

这套脚本 **不依赖 openclaw 命令**，适用于：
- openclaw 命令不存在
- gateway 起不来
- 需要重装系统后快速恢复

## 脚本列表

- `disaster-backup.sh`：一键全量备份
- `disaster-restore.sh`：一键恢复
- `disaster-verify.sh`：恢复后验收

## 一键备份

```bash
bash /root/.openclaw/workspace/ops/disaster-backup.sh
```

默认输出到：`/root/backups`

会生成：
- `openclaw-disaster-*.tgz`
- `openclaw-disaster-*.tgz.sha256`
- `openclaw-disaster-*.manifest.txt`

## 一键恢复

```bash
bash /root/.openclaw/workspace/ops/disaster-restore.sh /root/backups/openclaw-disaster-xxxx.tgz
```

- 会先校验 sha256（如果有）
- 会提示二次确认
- 会自动修复常见权限

## 恢复后验收

```bash
bash /root/.openclaw/workspace/ops/disaster-verify.sh
```

## 推荐流程（重装系统后）

1. 安装 Node 24 + npm（按你的标准流程）
2. 上传备份包到 VPS
3. 执行 `disaster-restore.sh`
4. 执行 `disaster-verify.sh`
5. 若 `openclaw` 可用，再执行：
   - `openclaw gateway install`
   - `openclaw gateway start`
   - `openclaw gateway status`
