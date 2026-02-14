# 功能/插件/技能 对照说明（中文）

你说得对：英文名看不懂会误操作。这个文档就是“英文名 -> 中文作用 -> 什么时候用”。

## 一、插件（Plugins）

> 插件状态可用：`bash /root/.openclaw/workspace/ops/plugin-manager.sh list`

### 1) memos-cloud-openclaw-plugin
- 中文：MemOS 云记忆插件
- 作用：把长期记忆读写接到 MemOS
- 什么时候开：你需要跨会话长期记忆
- 什么时候关：额度紧张、插件报错、先保主流程
- 开关命令：
  - 开：`bash /root/.openclaw/workspace/ops/plugin-manager.sh on memos-cloud-openclaw-plugin`
  - 关：`bash /root/.openclaw/workspace/ops/plugin-manager.sh off memos-cloud-openclaw-plugin`

## 二、技能（Skills）

查看当前技能清单：
```bash
bash /root/.openclaw/workspace/ops/skill-list.sh
```

常见内置技能：
- healthcheck：安全巡检/加固/版本状态
- weather：天气查询
- skill-creator：创建技能模板

## 三、脚本英文名速查

- `backup-workspace.sh`：工作区 git 备份
- `restore-workspace.sh`：从标签/分支恢复
- `watchdog-gateway.sh`：网关守护
- `model-failover-guard.sh`：模型守护
- `memory-pressure-guard.sh`：内存压力守护
- `antfarm-enable.sh`：启用 antfarm
- `antfarm-disable.sh`：停用 antfarm
- `cloud-backup.sh`：云端备份（small/full）
- `cloud-restore.sh`：云端恢复
- `disaster-backup.sh`：离线灾备备份（openclaw 挂了也能用）
- `disaster-restore.sh`：离线灾备恢复
- `disaster-verify.sh`：离线灾备验收

## 四、推荐最小操作路径（不容易错）

1) 日常：先备份（small）
2) 大改前：再做一次 full
3) 出问题：先诊断，再恢复
4) 恢复后：跑验收
