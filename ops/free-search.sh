#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <query> [limit]" >&2
  exit 1
fi

QUERY="$1"
LIMIT="${2:-8}"

python3 - "$QUERY" "$LIMIT" <<'PY'
import sys,requests,xml.etree.ElementTree as ET
q=sys.argv[1]
limit=int(sys.argv[2])
url='https://www.bing.com/search'
r=requests.get(url,params={'q':q,'format':'rss'},headers={'User-Agent':'Mozilla/5.0'},timeout=20)
r.raise_for_status()
root=ET.fromstring(r.text)
items=root.findall('.//item')[:limit]
for i,it in enumerate(items,1):
    title=(it.findtext('title') or '').strip()
    link=(it.findtext('link') or '').strip()
    desc=(it.findtext('description') or '').strip().replace('\n',' ')
    print(f"[{i}] {title}\n{link}\n{desc}\n")
PY