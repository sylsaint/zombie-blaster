#!/usr/bin/env python3
"""Build presentation-variant smoke APKs from one exported x86_64 APK.

The phone APK is not an input. Each variant keeps that APK's native library
and resources, and changes only assets/project.binary and/or assets/_cl_.

project.binary is ECFG: uint32 count, then uint32 key length, key bytes,
uint32 value length, encode_variant bytes. New values are copied from a
binary that Godot itself wrote (encode_present_settings.gd). Replacing the
whole file would dump every non-default setting.

_cl_ is uint32 count, then uint32 length and raw UTF-8 for each argument.
"""

from __future__ import annotations

import argparse
import struct
import sys
import zipfile
from pathlib import Path

SIGNATURE_SUFFIXES = (".sf", ".rsa", ".dsa", ".ec", ".mf")

# Keys copied out of the Godot-encoded binary. Values there are the
# non-default ones the variant needs.
SETTING_KEYS = {
    "swappy": (
        "display/window/frame_pacing/android/enable_frame_pacing",
    ),
    "vsync": (
        "display/window/vsync/vsync_mode",
    ),
    "gles": (
        "rendering/gl_compatibility/driver",
        "rendering/gl_compatibility/driver.android",
        "rendering/gl_compatibility/fallback_to_angle",
        "rendering/gl_compatibility/fallback_to_gles",
        "rendering/gl_compatibility/fallback_to_native",
    ),
    "threads": (
        "rendering/driver/threads/thread_model",
    ),
}


def parse_ecfg(data: bytes) -> list[tuple[str, bytes]]:
    if data[:4] != b"ECFG":
        raise ValueError("project.binary is not ECFG")
    count = struct.unpack_from("<I", data, 4)[0]
    pos = 8
    entries: list[tuple[str, bytes]] = []
    for _ in range(count):
        if pos + 4 > len(data):
            raise ValueError("project.binary ended inside a key length")
        key_len = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        key = data[pos : pos + key_len].decode("utf-8")
        pos += key_len
        value_len = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        value = data[pos : pos + value_len]
        pos += value_len
        entries.append((key, value))
    if pos != len(data):
        raise ValueError(f"project.binary has {len(data) - pos} trailing bytes")
    return entries


def write_ecfg(entries: list[tuple[str, bytes]]) -> bytes:
    out = bytearray(b"ECFG")
    out += struct.pack("<I", len(entries))
    for key, value in entries:
        key_bytes = key.encode("utf-8")
        out += struct.pack("<I", len(key_bytes))
        out += key_bytes
        out += struct.pack("<I", len(value))
        out += value
    return bytes(out)


def splice_settings(base: bytes, encoded: bytes, keys: tuple[str, ...]) -> bytes:
    entries = parse_ecfg(base)
    wanted = {key: value for key, value in parse_ecfg(encoded) if key in keys}
    missing = [key for key in keys if key not in wanted]
    if missing:
        raise SystemExit(f"encoded project.binary is missing {', '.join(missing)}")
    seen: set[str] = set()
    updated: list[tuple[str, bytes]] = []
    for key, value in entries:
        if key in wanted:
            updated.append((key, wanted[key]))
            seen.add(key)
        else:
            updated.append((key, value))
    for key in keys:
        if key not in seen:
            updated.append((key, wanted[key]))
    return write_ecfg(updated)


def parse_cl(data: bytes) -> list[str]:
    count = struct.unpack_from("<I", data, 0)[0]
    pos = 4
    args: list[str] = []
    for _ in range(count):
        length = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        args.append(data[pos : pos + length].decode("utf-8"))
        pos += length
    if pos != len(data):
        raise ValueError(f"_cl_ has {len(data) - pos} trailing bytes")
    return args


def write_cl(args: list[str]) -> bytes:
    out = bytearray(struct.pack("<I", len(args)))
    for arg in args:
        raw = arg.encode("utf-8")
        out += struct.pack("<I", len(raw))
        out += raw
    return bytes(out)


def with_present(args: list[str], name: str) -> list[str]:
    found = False
    out: list[str] = []
    for arg in args:
        if arg.startswith("--smoke-present="):
            out.append(f"--smoke-present={name}")
            found = True
        else:
            out.append(arg)
    if not found:
        insert_at = 0
        for index, arg in enumerate(out):
            if arg == "--smoke-canvas":
                insert_at = index + 1
                break
        out.insert(insert_at, f"--smoke-present={name}")
    return out


def command_line_for(name: str, args: list[str]) -> list[str]:
    updated = with_present(args, name)
    if name == "vsync" and "--disable-vsync" not in updated:
        updated.append("--disable-vsync")
    if name in ("nosafe", "edge") and "--edge_to_edge" not in updated:
        updated.append("--edge_to_edge")
    if name == "edge":
        updated = [arg for arg in updated if arg != "--fullscreen"]
    if name == "nosafe" and "--fullscreen" not in updated:
        raise SystemExit("nosafe variant lost --fullscreen; that is not the phone build")
    if name == "edge" and "--fullscreen" in updated:
        raise SystemExit("edge variant still has --fullscreen")
    return updated


def drop_signature(name: str) -> bool:
    base = name.rsplit("/", 1)[-1]
    return name.startswith("META-INF/") and base.lower().endswith(SIGNATURE_SUFFIXES)


def rewrite_apk(src: Path, dst: Path, project_binary: bytes | None, command_line: bytes | None) -> None:
    replaced = {"assets/project.binary": False, "assets/_cl_": False}
    with zipfile.ZipFile(src, "r") as zin, zipfile.ZipFile(dst, "w") as zout:
        for info in zin.infolist():
            if drop_signature(info.filename):
                continue
            data = zin.read(info.filename)
            if info.filename == "assets/project.binary" and project_binary is not None:
                data = project_binary
                replaced["assets/project.binary"] = True
            elif info.filename == "assets/_cl_" and command_line is not None:
                data = command_line
                replaced["assets/_cl_"] = True
            out = zipfile.ZipInfo(filename=info.filename, date_time=info.date_time)
            out.compress_type = info.compress_type
            out.external_attr = info.external_attr
            out.flag_bits = info.flag_bits
            out.create_system = info.create_system
            zout.writestr(out, data)
    if project_binary is not None and not replaced["assets/project.binary"]:
        raise SystemExit(f"{src} has no assets/project.binary")
    if command_line is not None and not replaced["assets/_cl_"]:
        raise SystemExit(f"{src} has no assets/_cl_")


def variant_names() -> list[str]:
    return ["swappy", "vsync", "gles", "threads", "nosafe", "edge"]


def build_variants(apk: Path, encoded: Path, out_dir: Path) -> list[Path]:
    with zipfile.ZipFile(apk) as zf:
        base_binary = zf.read("assets/project.binary")
        base_cl = parse_cl(zf.read("assets/_cl_"))
    encoded_bytes = encoded.read_bytes()
    # Fail before writing if the encoded file cannot supply every key.
    for name, keys in SETTING_KEYS.items():
        splice_settings(base_binary, encoded_bytes, keys)
    written: list[Path] = []
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in variant_names():
        keys = SETTING_KEYS.get(name)
        project_binary = splice_settings(base_binary, encoded_bytes, keys) if keys else None
        command_line = write_cl(command_line_for(name, base_cl))
        dest = out_dir / f"{apk.stem}-{name}.unsigned.apk"
        rewrite_apk(apk, dest, project_binary, command_line)
        with zipfile.ZipFile(dest) as zf:
            args = parse_cl(zf.read("assets/_cl_"))
            if f"--smoke-present={name}" not in args:
                raise SystemExit(f"{dest.name} is missing --smoke-present={name}")
            if name == "nosafe" and "--edge_to_edge" not in args:
                raise SystemExit(f"{dest.name} is missing --edge_to_edge")
            if name == "edge" and ("--edge_to_edge" not in args or "--fullscreen" in args):
                raise SystemExit(f"{dest.name} is not immersive-off edge-to-edge")
            if keys:
                packed = {key for key, _value in parse_ecfg(zf.read("assets/project.binary"))}
                missing = [key for key in keys if key not in packed]
                if missing:
                    raise SystemExit(f"{dest.name} lost settings: {', '.join(missing)}")
        written.append(dest)
        print(dest)
    return written


def _self_test() -> None:
    entries = [
        ("application/config/name", b"\x04\x00\x00\x00\x01\x00\x00\x00A\x00\x00\x00"),
        ("display/window/vsync/vsync_mode", b"\x02\x00\x00\x00\x01\x00\x00\x00"),
    ]
    blob = write_ecfg(entries)
    assert parse_ecfg(blob) == entries
    encoded = write_ecfg(
        [
            ("display/window/vsync/vsync_mode", b"\x02\x00\x00\x00\x00\x00\x00\x00"),
            ("display/window/frame_pacing/android/enable_frame_pacing", b"\x01\x00\x00\x00\x00\x00\x00\x00"),
            ("rendering/driver/threads/thread_model", b"\x02\x00\x00\x00\x02\x00\x00\x00"),
        ]
    )
    spliced = parse_ecfg(
        splice_settings(
            blob,
            encoded,
            ("display/window/frame_pacing/android/enable_frame_pacing",),
        )
    )
    assert spliced[1][0] == "display/window/vsync/vsync_mode"
    assert spliced[1][1].endswith(b"\x01\x00\x00\x00")
    assert spliced[-1][0].endswith("enable_frame_pacing")
    args = parse_cl(write_cl(["--", "--smoke-canvas", "--fullscreen", "--background_color", "#000000"]))
    nosafe = command_line_for("nosafe", args)
    assert "--edge_to_edge" in nosafe and "--fullscreen" in nosafe
    assert "--smoke-present=nosafe" in nosafe
    edge = command_line_for("edge", args)
    assert "--edge_to_edge" in edge and "--fullscreen" not in edge
    vsync = command_line_for("vsync", args)
    assert "--disable-vsync" in vsync and "--smoke-present=vsync" in vsync
    already = ["--", "--smoke-canvas", "--smoke-present=baseline", "--fullscreen"]
    swappy = command_line_for("swappy", already)
    assert swappy.count("--smoke-present=swappy") == 1
    assert "--smoke-present=baseline" not in swappy
    assert "--fullscreen" in swappy
    print("patch_present_apks self-test ok")


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        _self_test()
        return 0
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--encoded", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args(argv)
    build_variants(args.apk, args.encoded, args.out_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
