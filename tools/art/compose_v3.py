"""v3: assemble final preview PNGs from docs/art/samples/_raw (system python3 + Pillow).
Usage: python3 tools/art/compose_v3.py   (after blender ... render_v3.py -- tiers weapons zombies lods lineup_v4 beforeafter)"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose_previews import BG, INK, SUB, ROOT, S, font, inset, raw  # noqa: E402
import verify_glb as vg  # noqa: E402


def tris(folder):
    out = {}
    for f in os.listdir(folder):
        if f.endswith(".glb"):
            js, binc = vg.load(os.path.join(folder, f))
            out[f[:-4]] = sum(js["accessors"][pr["indices"]]["count"] // 3 for m in js["meshes"] for pr in m["primitives"])
    return out


M3 = os.path.join(ROOT, "assets", "models")
M2 = os.path.join(M3, "_v2")
CREDIT = "v3: rebuilt on Kenney Mini Characters / Graveyard Kit proportions (CC0, kenney.nl)"


def soldier_tiers(T):
    top, strip, game = raw("tiers_front"), raw("weapons"), raw("tiers_game")
    c = Image.new("RGB", (1600 + 560, top.height + strip.height + 70), BG)
    c.paste(top, (0, 0))
    c.paste(strip, (0, top.height + 50))
    d = ImageDraw.Draw(c)
    d.text((40, 30), "Squad gear tiers (v3, Kenney-style)", fill=INK, font=font(40))
    d.text((40, 82), "a: blue cap  |  b: teal helmet + vest + pack  |  c: gold helmet, plates, power pack."
           "  One shared aim pose; wpn_* attach at offset 0", fill=SUB, font=font(20, False))
    for x, t, wl in ((420, "a", "pistol"), (800, "b", "rifle / shotgun"), (1200, "c", "gatling / rocket")):
        lab = "chr_soldier_%s  %d tris" % (t, T["chr_soldier_" + t])
        d.text((x - d.textlength(lab, font=font(22)) / 2, top.height - 80), lab, fill=INK, font=font(22))
        lab2 = "tier %s weapons: %s" % ({"a": 1, "b": 2, "c": 3}[t], wl)
        d.text((x - d.textlength(lab2, font=font(18, False)) / 2, top.height - 50), lab2, fill=SUB,
               font=font(18, False))
    inset(c, game, (1600 + 20, 120), 0.325, "game camera (from behind)")
    d.text((1620, 120 + 340), "tier read from behind:\n cap blue / helmet teal / helmet gold\n"
           " guns held at the right hip so the\n big chibi head does not hide them", fill=SUB, font=font(18, False))
    d.line((40, top.height + 20, 1560, top.height + 20), fill=(214, 201, 176), width=2)
    for i, n in enumerate(["pistol", "rifle", "shotgun", "gatling", "rocket"]):
        cx = 140 + i * 330
        lab = "%d  wpn_%s  %d tris" % (i + 1, n, T["wpn_" + n])
        d.text((cx - d.textlength(lab, font=font(20)) / 2 + 30, top.height + 30), lab, fill=INK, font=font(20))
    d.text((1180, c.height - 34), CREDIT, fill=SUB, font=font(14, False))
    c.save(os.path.join(S, "sample_soldier_tiers.png"))


def zombies(T):
    top, game, lods = raw("zombies_front"), raw("zombies_game"), raw("lods")
    c = Image.new("RGB", (1600, 1000 + 300), BG)
    c.paste(top, (0, 0))
    d = ImageDraw.Draw(c)
    d.text((40, 30), "Zombies (v3, Kenney-style)", fill=INK, font=font(40))
    d.text((40, 82), "walker %d  |  runner %d  |  elite brute %d tris   (reach: grunts <= 0.6 m, elite <= 0.9 m)" % (
        T["enm_walker"], T["enm_runner"], T["enm_elite_brute"]), fill=SUB, font=font(20, False))
    inset(c, lods, (60, 1000), 0.62, "LOD1: walker %d -> %d   runner %d -> %d" % (
        T["enm_walker"], T["enm_walker_lod1"], T["enm_runner"], T["enm_runner_lod1"]))
    inset(c, game, (1600 - 432 - 60, 1000), 0.27, "game camera")
    d.text((40, 1265), CREDIT, fill=SUB, font=font(15, False))
    c.save(os.path.join(S, "sample_zombies.png"))


def lineup():
    im = raw("lineup_v4")
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((20, 1290, 1060, 1335), 10, fill=(244, 235, 217))
    d.text((36, 1300), "v4 lineup: 10 soldiers (a x3, b x4, c x3) vs runners, walkers (+LOD1 far rank), elite brute",
           fill=INK, font=font(18))
    assert im.size == (1080, 1350)
    im.save(os.path.join(S, "sample_lineup_v4.png"))


def before_after(T2, T3):
    a, b = raw("ba_v2"), raw("ba_v3")
    c = Image.new("RGB", (a.width, a.height * 2 + 140), BG)
    c.paste(a, (0, 70))
    c.paste(b, (0, a.height + 140))
    d = ImageDraw.Draw(c)
    keys = ["chr_soldier_a", "chr_soldier_b", "chr_soldier_c", "enm_walker", "enm_runner", "enm_elite_brute"]
    for y, lab, T in ((20, "BEFORE  v2 (own low-poly style)", T2), (a.height + 90, "AFTER  v3 (Kenney bevelled blocky chibi)", T3)):
        d.text((40, y), lab, fill=INK, font=font(34))
        d.text((900, y + 12), "tris  " + "  /  ".join(str(T[k]) for k in keys) + "   (soldier a/b/c, walker, runner, elite)",
               fill=SUB, font=font(18, False))
    c.save(os.path.join(S, "sample_v2_vs_v3.png"))


if __name__ == "__main__":
    T3, T2 = tris(M3), tris(M2)
    soldier_tiers(T3)
    zombies(T3)
    lineup()
    before_after(T2, T3)
    print("ok", T3)


def boss():
    """sample_boss.png: 3/4 front, game-camera close-up of the weak point, game-camera inset with squad + elite."""
    import verify_glb as v
    js, binc = v.load(os.path.join(M3, "boss_mutant.glb"))
    per = {n["name"]: js["accessors"][js["meshes"][n["mesh"]]["primitives"][0]["indices"]]["count"] // 3
           for n in js["nodes"] if "mesh" in n}
    front, weak, game = raw("boss_front"), raw("boss_weak").crop((60, 250, 1000, 900)), raw("boss_game")
    c = Image.new("RGB", (2200, 1560), BG)
    c.paste(front, (0, 150))
    d = ImageDraw.Draw(c)
    d.text((40, 30), "Boss: boss_mutant (Mutant Behemoth) - v3 Kenney-style", fill=INK, font=font(40))
    d.text((40, 84), "%d tris (body %d + weakpoint %d) <= 5000  |  5.2 m wide x 5.5 m tall (crystals)  |  "
           "forward reach 2.13 m, half-width 3.07 m (right arm) / 2.14 m (left)" % (
               sum(per.values()), per["boss_mutant"], per["weakpoint"]), fill=SUB, font=font(20, False))
    inset(c, weak, (1420, 150), 0.78, "game-camera close-up: weak point on the hump")
    d.text((1420, 150 + int(650 * 0.78) + 14), "separate mesh \"weakpoint\", material mat_weakpoint", fill=SUB, font=font(16, False))
    inset(c, game, (1420, 870), 0.34, "")
    d.text((1420 + 380, 880), "game camera\n(portrait 9:16)", fill=SUB, font=font(20))
    d.text((1420 + 380, 960), "boss 12 m in front of\n10 soldiers, elite\nalongside for scale\n\n"
           "boss ~47% of\nscreen width", fill=SUB, font=font(18, False))
    d.text((1420 + 380, 1170), "body: purple flesh,\noversized green\nmutant right arm,\nbone spikes\n\n"
           "weak point: orange /\nfire-yellow crystals\n(glow previewed with\nemission here; the\nengine drives it)",
           fill=SUB, font=font(16, False))
    d.text((40, 1520), "style only: chamfered boxes from tools/art/blocky_lib.py (Kenney-style, no Kenney mesh used)  |  "
           "generator tools/art/gen_boss_v3.py", fill=SUB, font=font(15, False))
    c.save(os.path.join(S, "sample_boss.png"))


if __name__ == "__main__":
    boss()
