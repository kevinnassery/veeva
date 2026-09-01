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
  cur=$(find . \( -path ./.claude -o -path ./docs \) -prune -o -name '*.ps1' -print0 \
          | xargs -0 grep -ho "ScriptVersion = '$today-[0-9]*'" 2>/dev/null \
          | tr -d "'" | sed 's/.*-//' | sort -n | tail -1 || true)
  # || true, and a default below: on the first bump of a day nothing carries today's
  # date, grep exits 1, and `set -o pipefail` turns that into the whole script exiting
  # without a word. It looks exactly like a bump that worked.
  [ -z "${cur:-}" ] && cur=0
  V="$today-$(( ${cur:-0} + 1 ))"
fi

# -prune ./.claude, not just ./docs. A git worktree lives under .claude/worktrees, and
# `find .` walked straight into it - so every bump also stamped the files of whatever
# branch was checked out there. Thirty-seven bumps in one day left another branch's
# working tree modified, which is not this script's business to touch.
for f in $(find . \( -path ./.claude -o -path ./docs \) -prune -o -name '*.ps1' -print); do
  if grep -q "^\$ScriptVersion" "$f"; then
    sed -i '' "s|^\$ScriptVersion = '.*'|\$ScriptVersion = '$V'|" "$f"
  else
    echo "  no version line in $f" >&2
  fi
done
for f in $(find . \( -path ./.claude -o -path ./docs \) -prune -o -name '*.bat' -print); do
  if grep -q '^REM VERSION' "$f"; then
    sed -i '' "s|^REM VERSION .*|REM VERSION $V|" "$f"
  else
    echo "  no version line in $f" >&2
  fi
done
echo "version $V"
