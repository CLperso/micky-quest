"""Remonte les échecs de `flutter test` en annotations GitHub."""
import sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
lines = text.splitlines()
failed = any(
    l.strip().startswith(("✖", "[E]", "❌")) or "Some tests failed" in l or (" failed." in l and "tests passed" in l)
    for l in lines
)
chunks, cur = [], []
for l in lines:
    if "[E]" in l or "══╡" in l or "EXCEPTION" in l:
        if cur:
            chunks.append("\n".join(cur))
        cur = [l]
    elif cur and len(cur) < 40:
        cur.append(l)
if cur:
    chunks.append("\n".join(cur))
for c in chunks[:20]:
    msg = c.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    print(f"::error title=test::{msg[:4000]}")
if failed:
    sys.exit(1)
