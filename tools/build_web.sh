#!/usr/bin/env bash
# Builds the browser version into export/web/ (playable on static hosts / Claude artifacts).
# - The 35 MB engine .wasm is gzipped to 8 MB to fit per-file limits; tools/web_shim.html
#   decompresses it in the browser (DecompressionStream).
# - Hosts that only serve standard web types get .wasm names for the .pck and .gz files;
#   the same shim maps the original names to them.
# Usage: GODOT=/path/to/godot tools/build_web.sh   (needs Godot 4.3 web export templates)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
rm -rf export/web && mkdir -p export/web
"$GODOT" --headless --export-release "Web" export/web/index.html
gzip -9 -c export/web/index.wasm > export/web/engine.gz.wasm && rm export/web/index.wasm
mv export/web/index.pck export/web/data.pck.wasm
python3 - <<'PY'
import re
p = "export/web/index.html"
s = open(p).read()
shim = open("tools/web_shim.html").read()
s = s.replace('<script src="index.js"></script>', shim + '<script src="index.js"></script>', 1)
# The artifact host supplies the document skeleton; keep only the content.
s = re.sub(r'<!DOCTYPE html>|</?html[^>]*>|</?head>|</?body>|<meta charset[^>]*>|<meta name="viewport"[^>]*>', '', s)
s = s.replace('<title>WITNESS</title>', '<title>WITNESS</title>\n<style>:root{color-scheme:dark;background:#000}</style>')
assert "DecompressionStream" in s and "data.pck.wasm" in s
open(p, "w").write(s)
PY
echo "Built export/web/. Test locally: python3 -m http.server -d export/web"
