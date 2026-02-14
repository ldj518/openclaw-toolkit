# 升级失败（OOM/Killed）一键恢复方案

## 固定SOP（2G机器强制执行）

1. **先做完整备份（必做）**
2. **优先 Tarball 升级**（不走 `npm install -g`）
3. **任何异常立刻恢复**（不要反复硬升）
4. **连续两次失败，直接走新系统冷安装**

---

## 1) 升级前完整备份（必做）
```bash
bash /root/.openclaw/workspace/openclaw-toolkit/ops/disaster-backup.sh /root/backups
```

## 2) 优先升级方式：Tarball（推荐）
```bash
bash /root/.openclaw/workspace/openclaw-toolkit/ops/update-by-tarball.sh 2026.2.13
# 或 latest
# bash /root/.openclaw/workspace/openclaw-toolkit/ops/update-by-tarball.sh
```

## 3) 安全升级（次选）
```bash
bash /root/.openclaw/workspace/openclaw-toolkit/ops/update-safe.sh
```
- 自动快照
- 升级后自动验收
- 失败自动回滚

## 4) 升级中断/被 kill：一键恢复
```bash
bash /root/.openclaw/workspace/openclaw-toolkit/ops/update-recover.sh
```

## 5) 命令都坏了：离线恢复
```bash
bash /root/.openclaw/workspace/openclaw-toolkit/ops/offline-recover.sh
# 或指定包
# bash /root/.openclaw/workspace/openclaw-toolkit/ops/offline-recover.sh /root/backups/xxx.tgz
```

## 6) 何时放弃就地升级，改冷安装
满足任一条件立即改新系统冷安装：
- 连续 2 次升级失败
- `openclaw` 命令持续丢失
- `gateway` 多次无法维持 active

## 关键文件
- 状态文件: `/root/.openclaw/update-safe.state`
- 日志文件: `/root/.openclaw/update-safe.log`
