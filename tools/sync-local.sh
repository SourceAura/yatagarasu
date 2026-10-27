#!/usr/bin/env bash
# sync-local.sh: make this machine's installed Yatagarasu match this repo.
# The repo is the source of truth. The script seats the design and the
# roost through the local catalogue tree (~/Documents/GitHub/ryostore-local,
# reached by the file:// override in ~/.config/ryoku/ryostore-base), then
# restarts the shell. It refuses to run without the override: without it,
# ryostore install would fetch the published catalogue instead.
# Releasing is a separate step: bump the version (design:
# tools/registry-design.json; roost: tools/registry-roost.json), then a PR.
set -euo pipefail
REPO="$HOME/Documents/GitHub/yatagarasu"
STAGE="$HOME/Documents/GitHub/ryostore-local"
BASE_FILE="$HOME/.config/ryoku/ryostore-base"

[ -f "$BASE_FILE" ] || { echo "sync-local: no catalogue override at $BASE_FILE: refusing."; exit 1; }
grep -q "$STAGE" "$BASE_FILE" || { echo "sync-local: override does not point at $STAGE: refusing."; exit 1; }

merge_row() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import json, sys
path, key, rowpath, rid = sys.argv[1:5]
d = json.load(open(path))
row = json.load(open(rowpath))
rows = d[key] if key else d
rows = [r for r in rows if r.get("id") != rid]
rows.append(row)
if key:
    d[key] = rows
else:
    d = rows
json.dump(d, open(path, "w"), indent=2, ensure_ascii=False)
print("registry row merged:", rid)
PY
}

echo "== design =="
mkdir -p "$STAGE/notifications/yatagarasu"
for f in Card.qml KasugaiCrow.qml README.md LICENSE; do
  cp "$REPO/$f" "$STAGE/notifications/yatagarasu/$f"
done
rm -rf "$STAGE/notifications/yatagarasu/assets" && cp -r "$REPO/assets" "$STAGE/notifications/yatagarasu/assets"
merge_row "$STAGE/notifications/registry.json" "notifications" "$REPO/tools/registry-design.json" "yatagarasu"
(cd "$STAGE" && python3 tools/pack-product.py notifications/yatagarasu)
jurai-storecheck notifications yatagarasu
ryostore remove notifications yatagarasu >/dev/null 2>&1 || true
ryostore install notifications yatagarasu

echo "== roost =="
rm -rf "$STAGE/plugins/yatagarasu-roost" && cp -r "$REPO/roost" "$STAGE/plugins/yatagarasu-roost"
merge_row "$STAGE/plugins/registry.json" "plugins" "$REPO/tools/registry-roost.json" "yatagarasu-roost"
(cd "$STAGE" && python3 tools/pack-product.py plugins/yatagarasu-roost)
ryoku plugin validate "$STAGE/plugins/yatagarasu-roost" | tail -1
ryoku plugin remove yatagarasu-roost >/dev/null 2>&1 || true
ryoku plugin add "$STAGE/plugins/yatagarasu-roost" --yes | tail -1
python3 - <<'PY'
import json
p = "/home/srcaura/.config/ryoku/plugins.json"
d = json.load(open(p))
e = d.get("yatagarasu-roost") or {}
pos = e.get("desktopWidget") or {"x": 1732, "y": 896}
d["yatagarasu-roost"] = {"enabled": True, "host": "desktopWidget",
                         "desktopWidget": pos, "settings": e.get("settings") or {}}
json.dump(d, open(p, "w"), indent=2)
print("roost enable entry reseeded")
PY

systemctl --user restart ryoku-shell
echo "sync-local: done. Shell restarted on the repo's current truth."
