import re, sys, pathlib
from bs4 import BeautifulSoup
from markdownify import markdownify as md

SRC = pathlib.Path(sys.argv[1]); DST = pathlib.Path(sys.argv[2])
BASE = "https://general.veevavault.dev/"

for f in sorted(SRC.rglob("*.html")):
    soup = BeautifulSoup(f.read_text(encoding="utf-8", errors="replace"), "html.parser")
    title = soup.title.get_text().replace(" | Vault Developer Portal", "").strip() if soup.title else f.stem
    main = soup.find("main")
    if main is None:
        print("no main:", f); continue
    for tag in main.select("script, style, nav, .right-sidebar, starlight-toc, mobile-starlight-toc, .pagination-links, footer"):
        tag.decompose()
    body = md(str(main), heading_style="ATX", strip=["img"], code_language="")
    body = re.sub(r"^\s*\[Section link for .*?\]\(#[^)]*\)\s*$", "", body, flags=re.M)
    body = re.sub(r"\n{3,}", "\n\n", body).strip()
    rel = f.relative_to(SRC).with_suffix(".md")
    out = DST / rel
    out.parent.mkdir(parents=True, exist_ok=True)
    url = BASE + str(f.relative_to(SRC).with_suffix("")) + "/"
    out.write_text(f"<!-- source: {url} -->\n<!-- title: {title} -->\n\n{body}\n", encoding="utf-8")
print("done")
