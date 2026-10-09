#!/usr/bin/env python3
"""Fail if scenes/, scripts/, or data/ use a character the UI fonts lack."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
CHARSET_PATH = ROOT / "assets" / "ui" / "fonts" / "charset.txt"
SCAN_DIRS = ("scenes", "scripts", "data")


def main() -> int:
    if not CHARSET_PATH.is_file():
        print(f"missing charset file: {CHARSET_PATH}", file=sys.stderr)
        return 1
    allowed = set(CHARSET_PATH.read_text(encoding="utf-8"))
    missing = {}
    for folder in SCAN_DIRS:
        base = ROOT / folder
        if not base.is_dir():
            print(f"missing scan directory: {base}", file=sys.stderr)
            return 1
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            data = path.read_bytes()
            try:
                text = data.decode("utf-8")
            except UnicodeDecodeError:
                print(f"not utf-8: {path.relative_to(ROOT)}", file=sys.stderr)
                return 1
            seen = set()
            rel = str(path.relative_to(ROOT))
            for ch in text:
                if ord(ch) < 128 or ch in allowed or ch in seen:
                    continue
                seen.add(ch)
                missing.setdefault(ch, []).append(rel)
    if missing:
        rel_charset = CHARSET_PATH.relative_to(ROOT)
        print(f"{len(missing)} character(s) missing from {rel_charset}:")
        for ch in sorted(missing, key=ord):
            files = ", ".join(missing[ch])
            print(f"  U+{ord(ch):04X} {ch}  {files}")
        return 1
    print(f"Charset covers every non-ASCII character in {', '.join(SCAN_DIRS)}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
