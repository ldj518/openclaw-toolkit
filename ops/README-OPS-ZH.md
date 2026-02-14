# OPS 中文总说明（给陛下）

位置：`/root/.openclaw/workspace/ops`

你现在可以不用记一堆脚本名，直接用总控台：

```bash
bash /root/.openclaw/workspace/ops/ops-menu-zh.sh
```

---

## 一、怎么用（最简单）

1. 运行总控台命令。
2. 按数字选分类（网关、备份恢复、Antfarm、MemOS、守护、XBot、其他工具）。
3. 每次执行后都有中文结果反馈：
   - ✅ 成功
   - ❌ 失败
4. “备份/恢复”中恢复操作是危险动作，会再次确认（必须输入 `YES`）。

---

## 二、常见场景对应菜单

### 场景 A：更新 OpenClaw
- 进入：`网关/更新`
- 先看：`检查更新`
- 再跑：`更新 OpenClaw（低内存模式）`
- 更新后看：`openclaw status` + `gateway status`

### 场景 B：备份 workspace
- 进入：`备份/恢复`
- 第一次先跑：`初始化备份仓库`
- 日常跑：`执行一次备份`
- 看历史点：`查看备份标签`

### 场景 C：恢复到某个备份点
- 进入：`备份/恢复`
- 选：`按标签恢复`
- 输入标签：如 `daily-2026-02-13`
- 注意：会覆盖当前未提交改动

### 场景 D：Antfarm 暂时不用，先冷配置
- 进入：`Antfarm（冷配置）`
- 看状态：`查看冷配置状态`
- 需要时再：`启用全部工作流` 或 `启用单个工作流`

### 场景 E：MemOS 临时关/开
- 进入：`MemOS 插件`
- 选：`开启` / `关闭` / `查看状态`

### 场景 F：网关异常，想保底修复
- 进入：`守护/定时任务`
- 跑：`执行一次网关守护`
- 再看：`快速诊断`

---

## 三、脚本分类索引（中文）

### 1) 网关/更新
- `openclaw gateway ...`（菜单内调用）

### 2) 备份/恢复
- `setup-backup.sh`：初始化本地 bare 仓库
- `backup-workspace.sh`：自动提交并推送备份 + daily 标签
- `restore-workspace.sh`：按分支或标签恢复（危险）

### 3) Antfarm
- `antfarm-cold-status.sh`：查看冷配置状态
- `antfarm-enable.sh`：启用
- `antfarm-disable.sh`：停用
- `README-antfarm-cold.md`：补充说明

### 4) MemOS
- `memosctl.sh`：on/off/status
- `memos-auto-switch.sh`：按日志自动切换

### 5) 守护与定时
- `watchdog-gateway.sh`：网关守护与异常回滚
- `model-failover-guard.sh`：模型守护封装
- `memory-pressure-guard.sh`：内存压力守护
- `install-cron.sh`：安装常用 cron

### 6) XBot
- `xbot-start.sh`
- `xbot-status.sh`
- `xbot-stop.sh`

### 7) 其他
- `free-search.sh`：免费搜索脚本
- `bird-x.sh`：X/Twitter 访问相关脚本
- `shared-env.sh`：环境变量文件（一般不直接执行）

---

## 四、风险提示（很重要）

- 恢复操作会覆盖当前改动，请先备份。
- 低内存机器更新时，尽量通过菜单里的“低内存更新模式”。
- 你项目的重渲染任务仍应在 Win11 本地执行，VPS 做轻控制。

---

## 五、你以后只记这两个命令就够

```bash
# 1) 打开总控台（中文菜单）
bash /root/.openclaw/workspace/ops/ops-menu-zh.sh

# 2) 快速看网关状态
openclaw gateway status
```
