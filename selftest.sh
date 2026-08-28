#!/usr/bin/env bash
# Local checks that do not need a vault. Run before pushing.
#   ./selftest.sh
cd "$(dirname "$0")"
PS=/usr/local/bin/pwsh-preview
pass=0; fail=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }

echo "== every path refresh.bat fetches exists in the repo =="
while read -r rel; do
  [ -z "$rel" ] && continue
  if [ -f "$rel" ]; then ok "$rel"; else bad "$rel  <- refresh.bat would 404"; fi
done < <(grep -o 'call :get [^ ]*' refresh.bat | sed 's/call :get //')

echo "== ini paths named in refresh.bat exist =="
while read -r rel; do
  [ -z "$rel" ] && continue
  if [ -f "$rel" ]; then ok "$rel"; else bad "$rel  <- ini hint points nowhere"; fi
done < <(grep -o '%B%/[A-Za-z0-9/._-]*\.ini' refresh.bat | sed 's|%B%/||' | sort -u)

echo "== scripts parse and call only defined commands =="
if $PS -NoProfile -File check-scripts.ps1 2>&1 | grep -q '^FAIL'; then
  $PS -NoProfile -File check-scripts.ps1 2>&1 | grep '^FAIL' | sed 's/^/  /'
  bad "check-scripts"
else
  ok "check-scripts ($($PS -NoProfile -File check-scripts.ps1 2>&1 | grep -c '^OK') scripts)"
fi

echo "== every version stamp matches =="
n=$(grep -h -E "^\\\$ScriptVersion|^REM VERSION" ./*.bat ./*/*/*.ps1 ./*/*/*.bat 2>/dev/null \
      | sed "s/.*= *'//;s/'.*//;s/^REM VERSION //" | sort -u | wc -l | tr -d ' ')
if [ "$n" = "1" ]; then ok "one version across all files"; else bad "$n different versions in the tree"; fi

echo "== gitignore covers the operator's input and output files =="
for f in attachments-map.csv documents-ids.txt session.txt validate-results.csv attachment-results.csv; do
  if git check-ignore -q "$f"; then ok "ignored: $f"; else bad "NOT ignored: $f"; fi
done
echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
