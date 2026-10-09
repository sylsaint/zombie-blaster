#!/usr/bin/env python3
"""Remove ART baseline profiles from a release APK and drop the old signature.

Godot 4.7's non-Gradle export copies android_release.apk, which AGP 8 already
filled with assets/dexopt/baseline.prof and baseline.profm. There is no preset
flag for that. Debug exports do not carry the profile. ART installs it only
for non-debuggable packages, which is the release APK and not the debug APK.

The caller zipaligns and re-signs the file this script writes.
"""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path

PROFILE_NAMES = {
    "baseline.prof",
    "baseline.profm",
    "startup.prof",
    "startup.profm",
}
SIGNATURE_SUFFIXES = (".sf", ".rsa", ".dsa", ".ec", ".mf")


def drop_entry(name: str) -> bool:
    base = name.rsplit("/", 1)[-1]
    if base in PROFILE_NAMES:
        return True
    if name.startswith("META-INF/") and base.lower().endswith(SIGNATURE_SUFFIXES):
        return True
    return False


def strip_apk(src: Path, dst: Path) -> list[str]:
    removed: list[str] = []
    with zipfile.ZipFile(src, "r") as zin, zipfile.ZipFile(dst, "w") as zout:
        for info in zin.infolist():
            if drop_entry(info.filename):
                removed.append(info.filename)
                continue
            data = zin.read(info.filename)
            out = zipfile.ZipInfo(filename=info.filename, date_time=info.date_time)
            out.compress_type = info.compress_type
            out.external_attr = info.external_attr
            out.flag_bits = info.flag_bits
            out.create_system = info.create_system
            zout.writestr(out, data)
    return removed


def _self_test() -> None:
    import io
    import tempfile

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        zf.writestr("assets/dexopt/baseline.prof", b"prof")
        zf.writestr("assets/dexopt/baseline.profm", b"profm")
        zf.writestr("META-INF/CERT.SF", b"sig")
        zf.writestr("META-INF/MANIFEST.MF", b"mf")
        info = zipfile.ZipInfo("lib/arm64-v8a/libgodot_android.so")
        info.compress_type = zipfile.ZIP_STORED
        zf.writestr(info, b"so-bytes")
        zf.writestr("assets/index.pck", b"pck-bytes")
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "in.apk"
        dst = Path(tmp) / "out.apk"
        src.write_bytes(buf.getvalue())
        removed = strip_apk(src, dst)
        with zipfile.ZipFile(dst) as zf:
            names = set(zf.namelist())
            so = zf.read("lib/arm64-v8a/libgodot_android.so")
            pck = zf.read("assets/index.pck")
            stored = zf.getinfo("lib/arm64-v8a/libgodot_android.so").compress_type
    assert "assets/dexopt/baseline.prof" in removed
    assert "assets/dexopt/baseline.profm" in removed
    assert "assets/dexopt/baseline.prof" not in names
    assert "META-INF/CERT.SF" not in names
    assert so == b"so-bytes" and stored == zipfile.ZIP_STORED
    assert pck == b"pck-bytes"
    print("strip_baseline_profile self-test ok")


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        _self_test()
        return 0
    if len(argv) != 2:
        print("usage: strip_baseline_profile.py INPUT.apk OUTPUT.apk", file=sys.stderr)
        return 2
    src, dst = Path(argv[0]), Path(argv[1])
    removed = strip_apk(src, dst)
    profiles = [name for name in removed if Path(name).name in PROFILE_NAMES]
    if not profiles:
        print(f"{src} has no baseline profile to remove", file=sys.stderr)
        return 1
    for name in removed:
        print(f"removed {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
