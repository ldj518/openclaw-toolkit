#!/usr/bin/env bash
set -euo pipefail

CONFIG="/root/.openclaw/openclaw.json"

usage(){
  cat <<'EOF'
用法:
  bash plugin-manager.sh list
  bash plugin-manager.sh status <插件ID>
  bash plugin-manager.sh on <插件ID>
  bash plugin-manager.sh off <插件ID>
EOF
}

list_plugins(){
python - <<'PY'
import json
p='/root/.openclaw/openclaw.json'
obj=json.load(open(p))
entries=obj.get('plugins',{}).get('entries',{})
if not entries:
    print('没有配置插件 entries')
else:
    for k,v in entries.items():
        print(f"{k}\t{'on' if v.get('enabled',False) else 'off'}")
PY
}

status_plugin(){
  local key="$1"
python - <<PY
import json
k='''$key'''
p='/root/.openclaw/openclaw.json'
obj=json.load(open(p))
entry=obj.get('plugins',{}).get('entries',{}).get(k)
if entry is None:
    print('missing')
else:
    print('on' if entry.get('enabled',False) else 'off')
PY
}

set_plugin(){
  local key="$1"; local target="$2"
python - <<PY
import json
p='/root/.openclaw/openclaw.json'
k='''$key'''
obj=json.load(open(p))
plugins=obj.setdefault('plugins',{})
entries=plugins.setdefault('entries',{})
entry=entries.setdefault(k,{})
entry['enabled']= True if '$target'=='on' else False
json.dump(obj,open(p,'w'),ensure_ascii=False,indent=2)
print('ok')
PY

  if command -v openclaw >/dev/null 2>&1; then
    openclaw gateway restart >/dev/null 2>&1 || true
  fi
  echo "已设置: $key => $target"
}

cmd="${1:-}"
case "$cmd" in
  list)
    list_plugins
    ;;
  status)
    [[ -n "${2:-}" ]] || { usage; exit 1; }
    status_plugin "$2"
    ;;
  on|off)
    [[ -n "${2:-}" ]] || { usage; exit 1; }
    set_plugin "$2" "$cmd"
    ;;
  *)
    usage; exit 1
    ;;
esac
