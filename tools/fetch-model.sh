#!/usr/bin/env bash
#
# Pulls a truck model straight from a URL into models/truck.glb, then inspects it.
#
#   ./tools/fetch-model.sh "https://example.com/truck.glb"
#   ./tools/fetch-model.sh "https://drive.google.com/uc?export=download&id=FILE_ID"
#
# Notes on the usual hosts:
#   - GitHub:   open the file, click "Raw", copy that URL.
#   - Dropbox:  replace "?dl=0" with "?raw=1".
#   - Drive:    https://drive.google.com/uc?export=download&id=<FILE_ID>
#   - WeTransfer / file.io: use the direct download link, not the landing page.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$PROJECT_ROOT/models/truck.glb"
TMP="$OUT.download"

if [ $# -ne 1 ]; then
	echo "usage: $0 <url-to-glb>" >&2
	exit 2
fi

URL="$1"
mkdir -p "$PROJECT_ROOT/models"

echo "==> downloading"
curl -L --fail --retry 3 --max-time 300 -o "$TMP" "$URL"

SIZE=$(wc -c <"$TMP")
echo "==> got $SIZE bytes"

if [ "$SIZE" -lt 1000 ]; then
	echo "!! that is too small to be a model — probably an HTML landing page." >&2
	echo "   Use the direct download link (GitHub Raw, Dropbox ?raw=1, Drive uc?export=download)." >&2
	rm -f "$TMP"
	exit 1
fi

mv "$TMP" "$OUT"
echo "==> saved to models/truck.glb"
echo

python3 "$PROJECT_ROOT/tools/inspect_glb.py" "$OUT" || {
	echo
	echo "!! the file did not pass inspection; delete models/truck.glb to fall back to the procedural truck." >&2
	exit 1
}

echo
echo "next: run ./tools/verify.sh, then godot --path . and take a job."
