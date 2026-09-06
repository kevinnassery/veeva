#!/usr/bin/env python3
"""Every question the tool can ask an operator must appear in the playbook.

Written after the operator hit "Save this to [submissions] vault in vault.ini? [Y/n]"
and the steps did not mention it. Both the code and the doc were mine, so that gap was
findable without her - by listing the prompts and reading the doc. Now the build does it.

A prompt not on the default submissions path is allowed here with a reason.
"""
import re, sys, os

ALLOW = {
    'Resume (keep them) or start Fresh': "only with -Existing Prompt; the playbook never passes it",
    'Answer y or n':                     "re-prompt on a bad answer, not a question of its own",
}

SRC = [os.path.join('VaultKit', f) for f in sorted(os.listdir('VaultKit')) if f.endswith('.ps1')]
SRC.append(os.path.join('src', 'vault.ps1'))
DOC = 'docs/submissions-load-runbook.md'

doc = open(DOC, encoding='utf-8').read().lower()

pat = re.compile(r"""(?:Read-Host|Read-VaultYesNo)\s+(?:-Prompt\s+)?(['"])(.+?)\1""")
found, missing = [], []
for path in SRC:
    for i, line in enumerate(open(path, encoding='utf-8'), 1):
        if line.lstrip().startswith('#'):
            continue
        for m in pat.finditer(line):
            raw = m.group(2)
            # Interpolation becomes a gap; match on the longest literal run around it.
            parts = re.split(r"\$\([^)]*\)|\$\w+", raw)
            frag = max((p.strip() for p in parts), key=len, default='').strip()
            if len(frag) < 10:
                continue
            found.append((path, i, raw, frag))

for path, i, raw, frag in found:
    if any(a.lower() in raw.lower() for a in ALLOW):
        continue
    if frag.lower() not in doc:
        missing.append((path, i, raw, frag))

print("prompts found: %d" % len(found))
for path, i, raw, frag in missing:
    print("UNDOCUMENTED %s:%d  %r  (looked for %r)" % (path, i, raw, frag))
sys.exit(1 if missing else 0)
