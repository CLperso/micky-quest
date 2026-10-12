"""Transforme les erreurs de `flutter analyze` en annotations GitHub,
lisibles depuis l'API, puis échoue s'il y a des erreurs."""
import re
import sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
errors = 0
for line in text.splitlines():
    m = re.match(r"\s*(error|warning)\s+•\s+(.*?)\s+•\s+(\S+?):(\d+):(\d+)\s+•\s+(\S+)", line)
    if not m:
        continue
    level, msg, path, ln, col, code = m.groups()
    kind = "error" if level == "error" else "warning"
    print(f"::{kind} file={path},line={ln},col={col}::{msg} ({code})")
    if level == "error":
        errors += 1
if errors:
    sys.exit(1)
