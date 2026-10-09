#!/usr/bin/env python3
"""Fail when a release-APK menu screenshot is a flat frame or 3D-only.

The main menu's primary button is the cream fill of btn_primary_normal.png
(about 255, 221, 161) and the title is gold (255, 209, 102). A lane-only
frame from the v0.1.0 release bug barely contains those pixels.
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

# Share of pixels that match the menu button / title. Level 1 gameplay is ~0.08%.
MIN_MENU_RATIO = 0.01
# Luma standard deviation below this is a blank or single-color frame.
MIN_LUMA_STDEV = 8.0


def is_menu_pixel(r: int, g: int, b: int) -> bool:
    return (
        r >= 210
        and g >= 160
        and 90 <= b <= 210
        and (r - b) >= 30
        and (g - b) >= 15
        and r + 10 >= g
    )


def _paeth(left: int, up: int, up_left: int) -> int:
    estimate = left + up - up_left
    dist_left = abs(estimate - left)
    dist_up = abs(estimate - up)
    dist_up_left = abs(estimate - up_left)
    if dist_left <= dist_up and dist_left <= dist_up_left:
        return left
    if dist_up <= dist_up_left:
        return up
    return up_left


def read_png_rgb(path: Path) -> tuple[int, int, bytearray]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    pos = 8
    width = height = bit_depth = color_type = interlace = None
    idat = bytearray()
    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _comp, _filt, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
        elif kind == b"IDAT":
            idat.extend(chunk)
        elif kind == b"IEND":
            break
    if width is None or height is None or bit_depth is None or color_type is None:
        raise ValueError(f"{path} is missing IHDR")
    if interlace:
        raise ValueError(f"{path} is interlaced")
    if bit_depth != 8 or color_type not in (2, 6):
        raise ValueError(f"{path} is not 8-bit RGB or RGBA (depth={bit_depth} type={color_type})")
    channels = 3 if color_type == 2 else 4
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    rows = bytearray()
    previous = bytearray(stride)
    offset = 0
    for _y in range(height):
        if offset >= len(raw):
            raise ValueError(f"{path} is truncated")
        filter_type = raw[offset]
        offset += 1
        row = bytearray(raw[offset : offset + stride])
        offset += stride
        if len(row) != stride:
            raise ValueError(f"{path} has a short scanline")
        out = bytearray(stride)
        for i, value in enumerate(row):
            left = out[i - channels] if i >= channels else 0
            up = previous[i]
            up_left = previous[i - channels] if i >= channels else 0
            if filter_type == 0:
                decoded = value
            elif filter_type == 1:
                decoded = value + left
            elif filter_type == 2:
                decoded = value + up
            elif filter_type == 3:
                decoded = value + ((left + up) // 2)
            elif filter_type == 4:
                decoded = value + _paeth(left, up, up_left)
            else:
                raise ValueError(f"{path} has PNG filter {filter_type}")
            out[i] = decoded & 255
        rows.extend(out)
        previous = out
    rgb = bytearray(width * height * 3)
    if channels == 3:
        rgb[:] = rows
    else:
        src = 0
        dst = 0
        for _ in range(width * height):
            rgb[dst : dst + 3] = rows[src : src + 3]
            src += 4
            dst += 3
    return width, height, rgb


def assess(width: int, height: int, rgb: bytearray) -> tuple[bool, str]:
    total = width * height
    if total <= 0:
        return False, "screenshot has no pixels"
    menu = 0
    count = 0
    mean = 0.0
    moment = 0.0
    # Every pixel for the menu color; every 16th pixel for spread.
    for y in range(height):
        row = y * width * 3
        for x in range(width):
            i = row + x * 3
            r = rgb[i]
            g = rgb[i + 1]
            b = rgb[i + 2]
            if is_menu_pixel(r, g, b):
                menu += 1
            if (x & 15) == 0 and (y & 15) == 0:
                luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                count += 1
                delta = luma - mean
                mean += delta / count
                moment += delta * (luma - mean)
    stdev = (moment / count) ** 0.5 if count else 0.0
    ratio = menu / total
    detail = f"menu_ratio={ratio:.4f} luma_stdev={stdev:.1f} size={width}x{height}"
    if stdev < MIN_LUMA_STDEV:
        return False, f"menu screenshot is mostly uniform ({detail})"
    if ratio < MIN_MENU_RATIO:
        return False, f"menu screenshot looks 3D-only, menu colors are missing ({detail})"
    return True, detail


def _self_test() -> None:
    width, height = 180, 320
    olive = (117, 129, 73)
    flat = bytearray(olive * (width * height))
    ok, message = assess(width, height, flat)
    assert not ok and "uniform" in message, message

    varied = bytearray(flat)
    for y in range(40, 200):
        for x in range(20, 160):
            i = (y * width + x) * 3
            varied[i : i + 3] = bytes((40 + (x % 50), 80, 30))
    ok, message = assess(width, height, varied)
    assert not ok and "3D-only" in message, message

    menu = bytearray(varied)
    for y in range(240, 300):
        for x in range(20, 160):
            i = (y * width + x) * 3
            menu[i : i + 3] = bytes((255, 221, 161))
    ok, message = assess(width, height, menu)
    assert ok, message

    encoded = _encode_png(width, height, menu)
    path = Path("/tmp/menu-check-self-test.png")
    path.write_bytes(encoded)
    got_w, got_h, got = read_png_rgb(path)
    assert (got_w, got_h) == (width, height)
    assert got == menu
    print("check_menu_screenshot self-test ok")


def _encode_png(width: int, height: int, rgb: bytearray) -> bytes:
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        raw.extend(rgb[y * stride : (y + 1) * stride])
    def chunk(kind: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b"")


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        _self_test()
        return 0
    if len(argv) != 1:
        print("usage: check_menu_screenshot.py MENU.png", file=sys.stderr)
        return 2
    width, height, rgb = read_png_rgb(Path(argv[0]))
    ok, message = assess(width, height, rgb)
    print(message)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
