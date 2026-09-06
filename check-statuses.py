#!/usr/bin/env python3
"""Every status value the playbook names must be one the code can actually write.

The playbook told the operator to expect WOULD_IMPORT from a plan run. No such string
exists anywhere in this repo - I invented it while writing the doc. The code writes
PLANNED. She would have run the check, seen something the steps did not list, and by the
standing rule at the top of the playbook, stopped.

Same failure as the undocumented prompt: the doc and the code were both mine and the
disagreement was mechanically findable.
"""
import re, sys, os

# Values that are real but not literals in the source.
KNOWN = {
    'TIMEOUT_AFTER_<n>_MIN': 'built at runtime from "TIMEOUT_AFTER_${TimeoutMinutes}_MIN"',
    'SUCCESS':               'a Vault job status, not a literal we write',
}

DOC = 'docs/submissions-load-runbook.md'
SRC = [os.path.join('VaultKit', f) for f in sorted(os.listdir('VaultKit')) if f.endswith('.ps1')]
SRC.append(os.path.join('src', 'vault.ps1'))
code = '\n'.join(open(p, encoding='utf-8').read() for p in SRC)
doc = open(DOC, encoding='utf-8').read()

# SHOUTY_SNAKE inside backticks is how the playbook writes a status.
cited = sorted(set(re.findall(r'`([A-Z][A-Z0-9_]{3,}(?:<[a-z]>[A-Z0-9_]*)*)`', doc)))
missing = [c for c in cited if c not in KNOWN and c not in code]

print("statuses cited by the playbook: %d" % len(cited))
for c in missing:
    print("NOT IN THE CODE  %r" % c)
sys.exit(1 if missing else 0)
