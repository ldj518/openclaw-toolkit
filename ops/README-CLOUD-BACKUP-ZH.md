# 云端备份恢复（GitHub + Cloudflare R2）

## 目标
- GitHub：备份 workspace 的 git 内容（非敏感）
- R2：备份全量加密包（.openclaw/.secrets/.ssh）

## 先准备密钥文件
创建：`/root/.secrets/cloud-backup.env`

```bash
R2_BUCKET=你的bucket
R2_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
BACKUP_PASSPHRASE=你自己设的强口令
```

## 配置 GitHub 远端（一次性）
在 workspace 仓库里执行：

```bash
git -C /root/.openclaw/workspace remote add backup-github <你的github仓库地址>
# 已有则改：
# git -C /root/.openclaw/workspace remote set-url backup-github <地址>
```

## 执行

### 1) 一键云备份（默认 small）
```bash
# small：只备份配置/记忆/脚本/技能（推荐）
bash /root/.openclaw/workspace/ops/cloud-backup.sh

# full：全量（含 .secrets/.ssh）
bash /root/.openclaw/workspace/ops/cloud-backup.sh full
```

### 2) 查看云端备份列表
```bash
bash /root/.openclaw/workspace/ops/cloud-list.sh
```

### 3) 一键云恢复
```bash
bash /root/.openclaw/workspace/ops/cloud-restore.sh openclaw-full-xxxx.tgz.enc
```

## 注意
- R2 里是加密包，没 `BACKUP_PASSPHRASE` 不能恢复。
- 不建议把 secrets 明文放 GitHub。
- 恢复会覆盖本机同名内容，务必先确认。
