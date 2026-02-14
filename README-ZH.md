# OpenClaw 工具包（一条命令安装）

## 1）发布到 GitHub
在 `openclaw-toolkit` 目录执行：

```bash
cd /root/.openclaw/workspace/openclaw-toolkit
git init
git add .
git commit -m "init openclaw toolkit"
# 换成你的仓库地址
git remote add origin <你的github仓库地址>
git branch -M main
git push -u origin main
```

## 2）新机器一条命令安装

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/<你的用户名>/<你的仓库名>/main/bootstrap-toolkit.sh)" -- <你的用户名>/<你的仓库名> main
```

## 3）安装后入口

```bash
bash /root/.openclaw/workspace/openclaw-toolkit/ops/onekit-menu-zh.sh
```

## 说明
- 脚本会自动安装依赖、创建 `.env` 模板、安装守护 cron、做首轮自检。
- secrets 不会随仓库上传，请在新机器填写：
  - `/root/.secrets/cloud-backup.env`
  - `/root/.secrets/offline-alert.env`
  - `/root/.secrets/pc-bridge.env`
