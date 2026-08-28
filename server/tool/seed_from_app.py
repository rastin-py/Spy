"""Re-export the app's built-in packs into `content/packs/`.

The packs compiled into the app are the same packs the catalogue offers, so
they are seeded from the one place they are already written down rather than
copied by hand. Run it after editing `lib/data/word_packs.dart`:

    python tool/seed_from_app.py

Packs that exist only on the server are not touched - this only rewrites files
whose id appears in the Dart source.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SERVER = Path(__file__).resolve().parent.parent
DART = SERVER.parent / "lib" / "data" / "word_packs.dart"
OUT = SERVER / "content" / "packs"

PACK = re.compile(
    r"WordPack\(\s*"
    r"id:\s*'(?P<id>[^']*)',\s*"
    r"language:\s*'(?P<language>[^']*)',\s*"
    r"name:\s*'(?P<name>[^']*)',\s*"
    r"(?:version:\s*(?P<version>\d+),\s*)?"
    r"words:\s*\[(?P<words>.*?)\],\s*\)",
    re.DOTALL,
)
WORD = re.compile(r"'((?:[^'\\]|\\.)*)'")


def main() -> int:
    source = DART.read_text(encoding="utf-8")
    OUT.mkdir(parents=True, exist_ok=True)

    found = 0
    for match in PACK.finditer(source):
        words = [w.replace("\\'", "'") for w in WORD.findall(match.group("words"))]
        if not words:
            continue
        pack = {
            "id": match.group("id"),
            "language": match.group("language"),
            "name": match.group("name"),
            "version": int(match.group("version") or 1),
            "words": words,
        }
        path = OUT / f"{pack['id']}.json"
        path.write_text(
            json.dumps(pack, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"{pack['id']:<10} {len(words):>4} words -> {path.name}")
        found += 1

    if not found:
        print("no packs matched - has word_packs.dart changed shape?", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
