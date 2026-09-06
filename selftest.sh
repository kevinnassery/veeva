#!/usr/bin/env bash
# Local checks that do not need a vault. Run before pushing.
#   ./selftest.sh
cd "$(dirname "$0")"
PS=/usr/local/bin/pwsh-preview
pass=0; fail=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }

echo "== the shipped vault.ps1 is what a build would produce =="
# It is generated, and it is the ONLY thing an operator downloads. A stale artifact means
# the fix that was committed is not the code that ships - which looks exactly like a fix
# that did not work.
if ./build.sh --check >/dev/null 2>&1; then ok "vault.ps1 is current with src/ and VaultKit/"
else bad "vault.ps1 is STALE - run ./build.sh"; fi

echo "== everything vault.ps1 update fetches exists in the repo =="
parts=$(sed -n 's/^\$VaultKitParts = @(\(.*\))$/\1/p' src/vault.ps1 | tr -d "' " | tr ',' '\n')
[ -z "$parts" ] && bad "could not read \$VaultKitParts out of src/vault.ps1"
for extra in README.md vault.ps1 vault.ini; do
  if [ -f "$extra" ]; then ok "$extra"; else bad "$extra  <- update would 404"; fi
done

echo "== the built file really is self-contained =="
# The point of building is that update fetches two files and neither can be half-applied.
# If the artifact still reaches for VaultKit\ at run time, that has silently stopped
# being true and the operator finds out on a bare folder.
if grep -q 'Join-Path (Join-Path \$here .VaultKit.)' vault.ps1; then
  bad "the built vault.ps1 still loads VaultKit/ at run time"
else ok "no run-time module load in the shipped file"; fi
for part in $parts; do
  if grep -q "^# ===== VaultKit/$part.ps1 =====$" vault.ps1; then ok "$part is inlined"
  else bad "$part is NOT in the built vault.ps1"; fi
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

echo "== the shipped vault.ps1 works entirely alone =="
# One file in an empty folder is now the whole install, so this is no longer a bootstrap
# corner - it is the normal case, and every command has to reach its dispatch on it.
t=$(mktemp -d)
cp vault.ps1 "$t/"
got=$($PS -NoProfile -File "$t/vault.ps1" version 2>&1 | tr -d '\r')
want=$(grep -m1 "^\$ScriptVersion" src/vault.ps1 | sed "s/.*= *'//;s/'.*//")
if [ "$got" = "$want" ]; then ok "version reported alone ($got)"; else bad "lone vault.ps1 version -> '$got', wanted '$want'"; fi
if $PS -NoProfile -File "$t/vault.ps1" help >/dev/null 2>&1; then ok "help works alone"; else bad "lone vault.ps1 help failed"; fi
# The real gain: a command that needs the module now reaches its own argument handling
# instead of dying on a missing file. It still stops at the config, which is not shipped.
if $PS -NoProfile -File "$t/vault.ps1" submissions 2>&1 | grep -q 'list|import'; then
  ok "a module command dispatches with nothing else on disk"
else bad "lone vault.ps1 could not dispatch 'submissions'"; fi
rm -rf "$t"

echo "== update can actually read the version it installs =="
# Get-VaultFileVersion reads only the first N lines. The stamp sits after the help block
# and the param block, and when N was 80 it never reached it - so update reported no
# version and the skew warning could not fire. A dead check reads like a passing one.
scan=$(sed -n 's/^\$script:VaultVersionScanLines = \([0-9]*\)$/\1/p' src/vault.ps1)
line=$(grep -n "^\$ScriptVersion = " vault.ps1 | head -1 | cut -d: -f1)
if [ -z "$scan" ] || [ -z "$line" ]; then
  bad "could not read the scan window ($scan) or the stamp line ($line)"
elif [ "$line" -le "$scan" ]; then
  ok "version stamp at line $line is inside the $scan-line scan window"
else
  bad "version stamp at line $line is PAST the $scan-line window - update cannot see it"
fi

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
         attachment-results.csv attachment-validate-results.csv \
         document-results.csv document-validate-results.csv \
         .vault-session.json; do
  if git check-ignore -q "$f"; then ok "ignored: $f"; else bad "NOT ignored: $f"; fi
done
echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
