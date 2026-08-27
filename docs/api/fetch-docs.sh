#!/usr/bin/env bash
# Re-mirror the Veeva Vault developer-portal pages listed in urls.txt as markdown.
# Requires: curl, uv (pulls beautifulsoup4 + markdownify into an ephemeral env).
#
# To change the pinned API version, edit urls.txt (or regenerate it from
# https://general.veevavault.dev/sitemap-index.xml) and re-run.
set -euo pipefail
cd "$(dirname "$0")"
base="https://general.veevavault.dev/"
raw="$(mktemp -d)"; trap 'rm -rf "$raw"' EXIT

while read -r u; do
  [ -n "$u" ] || continue
  rel="${u#"$base"}"; rel="${rel%/}"
  out="$raw/$rel.html"; mkdir -p "$(dirname "$out")"
  code=$(curl -sS -L --max-time 30 -o "$out" -w '%{http_code}' "$u")
  [ "$code" = 200 ] || echo "FAIL $code $u" >&2
  sleep 0.2
done < urls.txt

uv run --quiet --with beautifulsoup4 --with markdownify python html-to-md.py "$raw" .
echo "Mirrored $(grep -c . urls.txt) pages. Rebuild INDEX.md by hand if the page set changed."
