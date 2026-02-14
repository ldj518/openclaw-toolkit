# OpenClaw 离线救援工具包（中文）

这个工具包用于 **openclaw 命令失效/启动失败** 时的应急备份与恢复。

## 启动菜单

```bash
bash /root/.openclaw/workspace/rescue-kit/bin/kit-menu-zh.sh
```

## 功能

1. 一键备份（全量）
2. 一键恢复（从备份包）
3. 一键验收（恢复后）
4. OpenClaw 专用诊断
5. OpenClaw 一键救援安装（低内存）
6. 系统诊断（内存/磁盘/node）

## 也可单独执行

```bash
bash /root/.openclaw/workspace/rescue-kit/bin/disaster-backup.sh
bash /root/.openclaw/workspace/rescue-kit/bin/disaster-restore.sh /root/backups/xxx.tgz
bash /root/.openclaw/workspace/rescue-kit/bin/disaster-verify.sh
bash /root/.openclaw/workspace/rescue-kit/bin/openclaw-diagnose.sh
bash /root/.openclaw/workspace/rescue-kit/bin/openclaw-rescue-install.sh
```

## 打包带走（推荐）

```bash
tar -czf /root/rescue-kit-$(date +%F_%H%M%S).tgz -C /root/.openclaw/workspace rescue-kit
```
