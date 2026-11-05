"""Remonte les erreurs de build sous forme d'annotations GitHub."""
import sys

lines = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
keys = ("error", "what went wrong", "failed", "exception", "could not", "unresolved", "incompatible")
picked = []
for i, line in enumerate(lines):
    low = line.lower()
    if any(k in low for k in keys):
        picked.append("\n".join(lines[i:i + 6]))
# dédoublonne et limite
seen, out = set(), []
for p in picked:
    if p not in seen:
        seen.add(p)
        out.append(p)
for chunk in out[:40]:
    msg = chunk.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    print(f"::error title=build::{msg[:3000]}")
tail = "\n".join(lines[-60:]).replace("%", "%25").replace("\n", "%0A")
print(f"::error title=tail::{tail[:6000]}")
