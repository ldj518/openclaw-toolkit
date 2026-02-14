#!/usr/bin/env bash
set -euo pipefail

# 超低内存原子升级：
# - 先停 OpenClaw + 可选重服务
# - Tarball 方式升级（不走 npm install）
# - 失败自动回滚 + 自动拉起 OpenClaw + 打印失败原因
# - 成功自动拉起 OpenClaw + 验收

VER="${1:-latest}"
BASE="/usr/lib/node_modules"
DST="$BASE/openclaw"
BIN="/usr/bin/openclaw"
BACKUP_DIR="/root/backups"
TS="$(date +%F_%H%M%S)"
SNAP="$BACKUP_DIR/openclaw-preupgrade-${TS}.tgz"
TMP="$(mktemp -d)"
ROLLED=0
FAIL_REASON="unknown"

log(){ echo "[$(date '+%F %T')] $*"; }

cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT

rollback(){
  [[ $ROLLED -eq 1 ]] && return 0
  ROLLED=1
  log "[rollback] 恢复快照: $SNAP"
  tar -xzf "$SNAP" -C / || true
  chmod +x "$BIN" || true
  systemctl --user restart openclaw-gateway.service || true
}

on_err(){
  code=$?
  log "[x] 升级失败(code=$code): $FAIL_REASON"
  rollback
  log "[i] OpenClaw 已尝试自动拉起（失败可再执行: systemctl --user restart openclaw-gateway.service）"
  exit $code
}
trap on_err ERR

mkdir -p "$BACKUP_DIR" "$BASE"

# 0) 先做快照
log "做升级前快照: $SNAP"
tar -czf "$SNAP" "$DST" "$BIN" 2>/dev/null || true

# 1) 释放内存：停 OpenClaw + 可选后台服务（存在才停）
log "进入低内存模式：停止 OpenClaw 与可选后台服务"
systemctl --user stop openclaw-gateway.service || true
for s in docker containerd; do
  systemctl stop "$s" 2>/dev/null || true
done

# 2) 解析版本与下载 tarball
if [[ "$VER" == "latest" ]]; then
  TARGET_VER="$(npm view openclaw version)"
else
  TARGET_VER="$VER"
fi
TARBALL_URL="$(npm view openclaw@${TARGET_VER} dist.tarball)"
log "目标版本: $TARGET_VER"
log "下载: $TARBALL_URL"
curl -fsSL "$TARBALL_URL" -o "$TMP/openclaw.tgz" || { FAIL_REASON="tarball 下载失败"; exit 1; }

# 3) 解包
mkdir -p "$TMP/unpack"
tar -xzf "$TMP/openclaw.tgz" -C "$TMP/unpack" || { FAIL_REASON="tarball 解包失败"; exit 1; }
[[ -d "$TMP/unpack/package" ]] || { FAIL_REASON="tarball 包结构异常"; exit 1; }

# 4) 依赖预检（缺依赖直接失败回滚）
if [[ -f "$TMP/unpack/package/package.json" && -d "$DST/node_modules" ]]; then
  log "依赖预检（缺失则不切换）"
  missing=0
  while IFS= read -r dep; do
    [[ -d "$DST/node_modules/$dep" ]] || { echo "[x] 缺少依赖: $dep"; missing=1; }
  done < <(node -e 'const p=require(process.argv[1]); Object.keys(p.dependencies||{}).forEach(x=>console.log(x));' "$TMP/unpack/package/package.json")
  if [[ $missing -ne 0 ]]; then
    FAIL_REASON="依赖预检失败（现有 node_modules 无法满足新版本依赖）"
    exit 1
  fi
fi

# 5) 原子替换（保留旧 node_modules）
log "替换程序目录"
rm -rf "$DST.new"
mv "$TMP/unpack/package" "$DST.new"
if [[ -d "$DST/node_modules" && ! -d "$DST.new/node_modules" ]]; then
  cp -a "$DST/node_modules" "$DST.new/"
fi
rm -rf "$DST"
mv "$DST.new" "$DST"

cat > "$BIN" <<'EOF'
#!/usr/bin/env bash
exec node /usr/lib/node_modules/openclaw/dist/index.js "$@"
EOF
chmod +x "$BIN"

# 6) 自动拉起 + 验收
log "启动 OpenClaw"
systemctl --user restart openclaw-gateway.service
sleep 2

log "验收"
openclaw --version || { FAIL_REASON="openclaw 命令不可用"; exit 1; }
systemctl --user is-active openclaw-gateway.service | grep -q '^active$' || { FAIL_REASON="gateway 未处于 active"; exit 1; }
openclaw gateway status | sed -n '1,30p' >/dev/null || { FAIL_REASON="gateway status 检查失败"; exit 1; }

log "[ok] 升级成功: $TARGET_VER"
log "[ok] OpenClaw 已自动启动"
log "回滚快照: $SNAP"
