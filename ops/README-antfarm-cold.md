# Antfarm 冷配置（2G VPS 省资源模式）

已完成：
- 克隆源码：`/root/.openclaw/workspace/antfarm`
- 构建完成：`npm run build`
- CLI 可用：`antfarm v0.2.3`
- **未启用任何运行工作流/常驻任务**（冷态）

## 一键命令

- 查看冷态状态：
  - `bash /root/.openclaw/workspace/ops/antfarm-cold-status.sh`

- 启用（你明确说“现在开始用”时再执行）：
  - 全量：`bash /root/.openclaw/workspace/ops/antfarm-enable.sh`
  - 单工作流：`bash /root/.openclaw/workspace/ops/antfarm-enable.sh feature-dev`

- 停用（释放资源）：
  - `bash /root/.openclaw/workspace/ops/antfarm-disable.sh`

## 约束建议（按你当前策略）
- VPS 只跑轻量编排流程，不做视频渲染。
- 重任务继续在 Win11 本地执行。
- 启用前先确认远程入口稳定（SSH over FRP）。
