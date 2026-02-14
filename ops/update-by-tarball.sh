#!/usr/bin/env bash
set -euo pipefail

# 低内存升级（无 npm install，直接解包 npm tarball）
# 用法：bash update-by-tarball.sh [version]
# 例：bash update-by-tarball.sh 2026.2.13

VER="${1:-latest}"
BASE="/usr/lib/node_modules"
DST="$BASE/openclaw"
BIN="/usr/bin/openclaw"
BACKUP_DIR="/root/backups"
TS="$(date +%F_%H%M%S)"
SNAP="$BACKUP_DIR/openclaw-preupgrade-${TS}.tgz"
TMP="$(mktemp -d)"
ROLLED_BACK=0

log(){ echo "[$(date '+%F %T')] $*"; }

rollback(){
  if [[ $ROLLED_BACK -eq 1 ]]; then return 0; fi
  ROLLED_BACK=1
  if [[ -f "$SNAP" ]]; then
    log "[rollback] 恢复快照: $SNAP"
    tar -xzf "$SNAP" -C / || true
    chmod +x "$BIN" || true
    systemctl --user restart openclaw-gateway.service || true
  fi
}

cleanup(){
  rm -rf "$TMP"
}

on_err(){
  code=$?
  log "[x] Tarball升级失败，触发自动回滚（code=$code）"
  rollback
  exit "$code"
}
trap on_err ERR
trap cleanup EXIT

mkdir -p "$BACKUP_DIR" "$BASE"

if [[ -d "$DST" || -f "$BIN" ]]; then
  log "做升级前快照: $SNAP"
  tar -czf "$SNAP" "$DST" "$BIN" 2>/dev/null || true
fi

if [[ "$VER" == "latest" ]]; then
  TARGET_VER="$(npm view openclaw version)"
else
  TARGET_VER="$VER"
fi

TARBALL_URL="$(npm view openclaw@${TARGET_VER} dist.tarball)"
log "目标版本: $TARGET_VER"
log "下载: $TARBALL_URL"
curl -fsSL "$TARBALL_URL" -o "$TMP/openclaw.tgz"

log "解包"
mkdir -p "$TMP/unpack"
tar -xzf "$TMP/openclaw.tgz" -C "$TMP/unpack"
[[ -d "$TMP/unpack/package" ]] || { echo "[x] 包结构异常"; exit 1; }

# 预检：新版本依赖是否在现有 node_modules 中可满足（避免切换后缺包直接崩）
if [[ -f "$TMP/unpack/package/package.json" && -d "$DST/node_modules" ]]; then
  log "依赖预检（基于现有 node_modules）"
  missing=0
  while IFS= read -r dep; do
    [[ -d "$DST/node_modules/$dep" ]] || {
      echo "[x] 缺少依赖: $dep"
      missing=1
    }
  done < <(node -e 'const p=require(process.argv[1]); const d=Object.keys(p.dependencies||{}); d.forEach(x=>console.log(x));' "$TMP/unpack/package/package.json")

  if [[ $missing -ne 0 ]]; then
    echo "[x] 依赖预检失败：当前机器缺少新版本依赖，停止切换。"
    echo "    建议：走新系统冷安装，或先在维护窗口补依赖后再试。"
    exit 1
  fi
fi

log "停止 gateway"
systemctl --user stop openclaw-gateway.service || true
sleep 1

log "替换程序目录"
rm -rf "$DST.new"
mv "$TMP/unpack/package" "$DST.new"

# 关键：保留旧 node_modules，避免 tarball 无依赖导致运行失败
if [[ -d "$DST/node_modules" && ! -d "$DST.new/node_modules" ]]; then
  log "复用旧依赖目录 node_modules"
  cp -a "$DST/node_modules" "$DST.new/"
fi

rm -rf "$DST"
mv "$DST.new" "$DST"

cat > "$BIN" <<'EOF'
#!/usr/bin/env bash
exec node /usr/lib/node_modules/openclaw/dist/index.js "$@"
EOF
chmod +x "$BIN"

log "重启 gateway"
systemctl --user restart openclaw-gateway.service
sleep 2

log "验收"
openclaw --version
systemctl --user is-active openclaw-gateway.service
openclaw gateway status | sed -n '1,30p'

log "升级完成。回滚快照: $SNAP"
