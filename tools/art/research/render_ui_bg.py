"""Portrait 1080x1920 game-camera background for the UI mockups (our v2 models; the elite brute scaled up
stands in for the boss, which is not modelled yet).
Usage: blender -b --factory-startup -P tools/art/research/render_ui_bg.py"""
import math, os, sys
import bpy
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
import render_previews as rp  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "research", "_raw", "ui_bg.png")
rp.setup_scene()
bpy.context.scene.cycles.samples = 32
rp._cache.clear()
rp.lane(width=7.5, y0=-8, y1=40)
rows = [(-1.65, 0.0), (-0.55, 0.0), (0.55, 0.0), (1.65, 0.0), (-1.1, 1.0), (0.0, 1.0), (1.1, 1.0), (-0.55, 2.0), (0.55, 2.0),
        (-2.2, 1.0), (2.2, 1.0), (-1.65, 2.0), (1.65, 2.0)]
for i, (x, y) in enumerate(rows):
    t, w = ("c", "wpn_gatling") if i in (5,) else ("b", "wpn_rifle" if i % 2 else "wpn_shotgun")
    rp.instance("chr_soldier_" + t, x, y, 0)
    rp.instance(w, x, y, 0)
    rp.blob(x, y + 0.05, 0.48)
for x, y, r in [(-2.4, 7.5, 8), (2.5, 7.8, -10), (-1.6, 8.6, 5), (1.7, 8.9, -6)]:
    rp.instance("enm_walker", x, y, 180 + r)
    rp.blob(x, y, 0.55)
boss = rp.instance("enm_elite_brute", 0.0, 12.0, 180)
boss.scale = (1.7, 1.7, 1.7)
rp.blob(0.0, 11.9, 2.0)
rp.hide_templates()
rp.camera((0, 6.2, 0.6), 15.5, 50, 0, 52)
rp.render(OUT, 1080, 1920)
