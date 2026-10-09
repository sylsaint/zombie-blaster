"""v2: assemble final preview PNGs from docs/art/samples/_raw (system python3 + Pillow)."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
S = os.path.join(ROOT, "docs", "art", "samples")
RAW = os.path.join(S, "_raw")
BG = (244, 235, 217)
INK = (26, 26, 31)
SUB = (74, 78, 84)


def font(sz, bold=True):
    f = "/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if bold else "")
    return ImageFont.truetype(f, sz) if os.path.exists(f) else ImageFont.load_default()


def tris():
    """Triangle counts straight from the exported glbs (via verify_glb loader)."""
    sys.path.insert(0, os.path.dirname(__file__))
    import verify_glb as vg
    out = {}
    for f in os.listdir(os.path.join(ROOT, "assets", "models")):
        if f.endswith(".glb"):
            js, binc = vg.load(os.path.join(ROOT, "assets", "models", f))
            n = 0
            for m in js["meshes"]:
                for pr in m["primitives"]:
                    n += js["accessors"][pr["indices"]]["count"] // 3
            out[f[:-4]] = n
    return out


def raw(n):
    return Image.open(os.path.join(RAW, n + ".png")).convert("RGB")


def inset(canvas, img, xy, scale, label):
    im = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    x, y = xy
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((x - 4, y - 4, x + im.width + 4, y + im.height + 4), 10, outline=(214, 201, 176), width=3)
    canvas.paste(im, (x, y))
    d.text((x + 10, y + 8), label, fill=SUB, font=font(18))


def soldier_tiers(T):
    top, strip, game = raw("tiers_front"), raw("weapons"), raw("tiers_game")
    c = Image.new("RGB", (1600 + 560, top.height + strip.height + 70), BG)
    c.paste(top, (0, 0))
    c.paste(strip, (0, top.height + 50))
    d = ImageDraw.Draw(c)
    d.text((40, 30), "Squad gear tiers (v2)", fill=INK, font=font(40))
    d.text((40, 82), "same pose, same blue squad; weapons are separate meshes at offset 0", fill=SUB, font=font(20, False))
    for x, t, w, wl in ((330, "a", "pistol", "pistol"), (800, "b", "rifle", "rifle / shotgun"),
                        (1240, "c", "gatling", "gatling / rocket")):
        lab = "chr_soldier_%s  %d tris" % (t, T["chr_soldier_" + t])
        d.text((x - d.textlength(lab, font=font(22)) / 2, top.height - 120), lab, fill=INK, font=font(22))
        lab2 = "tier %s weapons: %s" % ({"a": 1, "b": 2, "c": 3}[t], wl)
        d.text((x - d.textlength(lab2, font=font(18, False)) / 2, top.height - 90), lab2, fill=SUB, font=font(18, False))
    inset(c, game, (1600 + 20, 120), 0.325, "game camera (from behind)")
    d.line((40, top.height + 20, 1560, top.height + 20), fill=(214, 201, 176), width=2)
    names = ["pistol", "rifle", "shotgun", "gatling", "rocket"]
    for i, n in enumerate(names):
        cx = 140 + i * 330
        lab = "%d  wpn_%s  %d tris" % (i + 1, n, T["wpn_" + n])
        d.text((cx - d.textlength(lab, font=font(20)) / 2 + 30, top.height + 30), lab, fill=INK, font=font(20))
    c.save(os.path.join(S, "sample_soldier_tiers.png"))


def zombies(T):
    top, game, lods = raw("zombies_front"), raw("zombies_game"), raw("lods")
    c = Image.new("RGB", (1600, 1000 + 300), BG)
    c.paste(top, (0, 0))
    d = ImageDraw.Draw(c)
    d.text((40, 30), "Zombies (v2)", fill=INK, font=font(40))
    d.text((40, 82), "walker %d  |  runner %d  |  elite brute %d tris" % (
        T["enm_walker"], T["enm_runner"], T["enm_elite_brute"]), fill=SUB, font=font(20, False))
    inset(c, lods, (60, 1000), 0.62,
          "LOD: walker %d -> %d   runner %d -> %d" % (T["enm_walker"], T["enm_walker_lod1"],
                                                      T["enm_runner"], T["enm_runner_lod1"]))
    inset(c, game, (1600 - 432 - 60, 1000), 0.27, "game camera")
    c.save(os.path.join(S, "sample_zombies.png"))


if __name__ == "__main__":
    T = tris()
    soldier_tiers(T)
    zombies(T)
    if os.path.exists(os.path.join(RAW, "lineup_v3.png")):
        raw("lineup_v3").save(os.path.join(S, "sample_lineup_v3.png"))
