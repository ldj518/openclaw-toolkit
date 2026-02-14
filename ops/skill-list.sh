#!/usr/bin/env bash
set -euo pipefail

echo "== 系统内置技能 =="
if [[ -d /usr/lib/node_modules/openclaw/skills ]]; then
  find /usr/lib/node_modules/openclaw/skills -maxdepth 2 -name SKILL.md | while read -r f; do
    d=$(basename "$(dirname "$f")")
    desc=$(grep -m1 '^description:' "$f" | sed 's/^description:[ ]*//')
    echo "- $d : ${desc:-无描述}"
  done
else
  echo "(未找到系统技能目录)"
fi

echo
echo "== 工作区自定义技能 =="
if [[ -d /root/.openclaw/workspace/skills ]]; then
  find /root/.openclaw/workspace/skills -maxdepth 2 -name SKILL.md | while read -r f; do
    d=$(basename "$(dirname "$f")")
    desc=$(grep -m1 '^description:' "$f" | sed 's/^description:[ ]*//')
    echo "- $d : ${desc:-无描述}"
  done
else
  echo "(无自定义技能目录)"
fi
