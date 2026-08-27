#!/usr/bin/env bash
# Stamp every script with one version string. Run before committing a change that
# operators will download, so "which version am I running" is answerable on sight.
#   ./bump-version.sh            -> today's date plus the next serial for today
#   ./bump-version.sh 2026.08.26-9
set -euo pipefail
cd "$(dirname "$0")"

if [ $# -ge 1 ]; then
  V="$1"
else
  today=$(date '+%Y.%m.%d')
  cur=$(grep -ho "ScriptVersion = '$today-[0-9]*'" ./*.ps1 2>/dev/null | grep -o '[0-9]*$' | sort -n | tail -1 || true)
  V="$today-$(( ${cur:-0} + 1 ))"
fi

for f in ./*.ps1; do
  if grep -q "^\$ScriptVersion" "$f"; then
    sed -i '' "s|^\$ScriptVersion = '.*'|\$ScriptVersion = '$V'|" "$f"
  else
    echo "  no version line in $f" >&2
  fi
done
for f in ./*.bat; do
  if grep -q '^REM VERSION' "$f"; then
    sed -i '' "s|^REM VERSION .*|REM VERSION $V|" "$f"
  else
    echo "  no version line in $f" >&2
  fi
done
echo "version $V"
