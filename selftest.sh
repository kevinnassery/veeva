#!/usr/bin/env bash
# Local checks that do not need a vault. Run before pushing.
#   ./selftest.sh
cd "$(dirname "$0")"
PS=/usr/local/bin/pwsh-preview
pass=0; fail=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }

echo "== everything vault.ps1 update fetches exists in the repo =="
# The manifest is built from $VaultKitParts, so the parts list is what has to be checked:
# a module file that is loaded but never fetched is the failure this catches.
parts=$(sed -n 's/^\$VaultKitParts = @(\(.*\))$/\1/p' vault.ps1 | tr -d "' " | tr ',' '\n')
[ -z "$parts" ] && bad "could not read \$VaultKitParts out of vault.ps1"
for part in $parts; do
  if [ -f "VaultKit/$part.ps1" ]; then ok "VaultKit/$part.ps1"; else bad "VaultKit/$part.ps1  <- update would 404"; fi
done
for extra in README.md vault.ps1 vault.ini; do
  if [ -f "$extra" ]; then ok "$extra"; else bad "$extra  <- update would 404"; fi
done

echo "== every module file is in the parts list =="
# The other direction: a file added to VaultKit/ but not loaded is dead weight that
# update would never deliver.
for f in VaultKit/*.ps1; do
  name=$(basename "$f" .ps1)
  if echo "$parts" | grep -qx "$name"; then ok "$name is loaded"; else bad "VaultKit/$name.ps1 is not in \$VaultKitParts"; fi
done

echo "== scripts parse and call only defined commands =="
if $PS -NoProfile -File check-scripts.ps1 2>&1 | grep -q '^FAIL\|^PARSE\|^SHADOW'; then
  $PS -NoProfile -File check-scripts.ps1 2>&1 | grep '^FAIL\|^PARSE\|^SHADOW' | sed 's/^/  /'
  bad "check-scripts"
else
  ok "check-scripts ($($PS -NoProfile -File check-scripts.ps1 2>&1 | grep -c '^OK') scripts)"
fi

echo "== the module tests pass =="
if $PS -NoProfile -File tests/VaultKit.Tests.ps1 >/tmp/vk-tests.$$ 2>&1; then
  ok "VaultKit.Tests ($(grep -c 'PASS' /tmp/vk-tests.$$) assertions)"
else
  grep 'FAIL' /tmp/vk-tests.$$ | sed 's/^/  /'
  bad "VaultKit.Tests"
fi
rm -f /tmp/vk-tests.$$

echo "== vault.ps1 runs with no VaultKit beside it =="
# update has to work on a bare folder - that is the whole bootstrap.
t=$(mktemp -d)
cp vault.ps1 "$t/"
got=$($PS -NoProfile -File "$t/vault.ps1" version 2>&1 | tr -d '\r')
want=$(grep -m1 "^\$ScriptVersion" vault.ps1 | sed "s/.*= *'//;s/'.*//")
if [ "$got" = "$want" ]; then ok "version reported without the module ($got)"; else bad "bare vault.ps1 version -> '$got', wanted '$want'"; fi
if $PS -NoProfile -File "$t/vault.ps1" help >/dev/null 2>&1; then ok "help works without the module"; else bad "bare vault.ps1 help failed"; fi
rm -rf "$t"

echo "== every version stamp matches =="
# -prune the stray worktree under .claude/: it is a checkout of another commit, so its
# stamps are legitimately different and counting them reports skew that is not there.
n=$(find . \( -path ./.claude -o -path ./docs \) -prune -o \( -name '*.ps1' -o -name '*.bat' \) -print | \
      xargs grep -h -E "^\\\$ScriptVersion|^REM VERSION" 2>/dev/null \
      | sed "s/.*= *'//;s/'.*//;s/^REM VERSION //" | sort -u | wc -l | tr -d ' ')
if [ "$n" = "1" ]; then ok "one version across all files"; else bad "$n different versions in the tree"; fi

echo "== no vault hostnames are committed =="
# Scrubbed once already. A real hostname in a tracked file is a customer name in public.
if git grep -ilE '(mallinckrodt|endo)[a-z-]*\.veevavault\.com' -- . >/dev/null 2>&1; then
  git grep -ilE '(mallinckrodt|endo)[a-z-]*\.veevavault\.com' -- . | sed 's/^/  /'
  bad "a real vault hostname is tracked"
else
  ok "no real vault hostnames tracked"
fi

echo "== gitignore covers the operator's input and output files =="
for f in attachments-map.csv documents-ids.txt session.txt validate-results.csv \
         attachment-results.csv document-results.csv document-validate-results.csv \
         .vault-session.json; do
  if git check-ignore -q "$f"; then ok "ignored: $f"; else bad "NOT ignored: $f"; fi
done
echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
