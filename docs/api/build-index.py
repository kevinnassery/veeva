"""Regenerate INDEX.md from the mirrored markdown tree. Run from docs/api/."""
import pathlib, re
root = pathlib.Path('.')
files = sorted(p for p in root.rglob('*.md') if p.name != 'INDEX.md')

def title(p):
    m = re.search(r'<!-- title: (.*?) -->', p.read_text(encoding='utf-8'))
    return m.group(1) if m else p.stem

def group(p):
    parts = p.parts
    if 'getting-started' in parts: return 'Getting started'
    if 'guides' in parts:
        return 'Guides — RIM' if parts[0] == 'regulatory' else 'Guides — platform'
    if 'api-reference' in parts:
        i = parts.index('api-reference')
        sec = parts[i + 2] if len(parts) > i + 2 else '(index)'
        if sec.endswith('.md'): sec = '(index)'
        return ('RIM' if parts[0] == 'regulatory' else 'Platform') + ' — ' + sec
    return 'Other'

groups = {}
for p in files: groups.setdefault(group(p), []).append(p)

out = ["# Veeva Vault API reference — local mirror (v26.2)\n",
       "Offline copy of the Vault Developer Portal pages this repo depends on, converted to",
       "markdown. Each file keeps its source URL in an HTML comment at the top. Regenerate the",
       "pages with `fetch-docs.sh` and this index with `python3 build-index.py > INDEX.md`.\n",
       "Scope: RIM Submissions Archive, documents (incl. bulk update/export and document",
       "workflows), authentication, file staging, jobs, VQL, vault objects, Vault Loader, errors.\n"]
for g in sorted(groups):
    out.append(f"## {g}\n")
    out += [f"- [{title(p)}]({p})" for p in sorted(groups[g], key=str)]
    out.append("")
print("\n".join(out))
