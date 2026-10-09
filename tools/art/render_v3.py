"""v3 preview renders (reuses render_previews helpers). Raw views -> docs/art/samples/_raw/.
Usage: blender -b --factory-startup -P tools/art/render_v3.py -- [job ...]
jobs: check tiers weapons zombies lods lineup_v4 beforeafter
"""
import math
import os
import sys
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render_previews as rp  # noqa: E402

ROOT = rp.ROOT
V3 = os.path.join(ROOT, "assets", "models")
V2 = os.path.join(ROOT, "assets", "models", "_v2")
RAW = rp.RAW
SAMPLES = 32


def setup():
    sc = rp.setup_scene()
    sc.cycles.samples = SAMPLES
    rp._cache.clear()
    rp.MODELS = V3
    return sc


def check():
    """turntable-ish check sheet: front, side, back of every character."""
    setup()
    names = ["chr_soldier_a", "chr_soldier_b", "chr_soldier_c", "enm_walker", "enm_walker_lod1", "enm_runner",
             "enm_runner_lod1"]
    for i, n in enumerate(names):
        x = 3.3 - i * 1.1
        rp.instance(n, x, 0, 0)
        if n.startswith("chr"):
            rp.instance("wpn_rifle", x, 0, 0)
    hide = rp.hide_templates
    hide()
    rp.view(os.path.join(RAW, "check_front.png"), 1800, 600, (0, 0, 0.85), 11, 8, 0, 18, True)
    rp.view(os.path.join(RAW, "check_back.png"), 1800, 600, (0, 0, 0.85), 11, 30, 0, 18, False)
    for o in list(bpy.data.objects):
        if o.name.endswith("_inst"):
            o.rotation_euler[2] = math.radians(90)
    rp.view(os.path.join(RAW, "check_side.png"), 1800, 600, (0, 0, 0.85), 11, 8, 0, 18, True)


def check_elite():
    setup()
    rp.instance("enm_elite_brute", 1.6, 0, 0)
    rp.instance("enm_elite_brute", -1.6, 0, 90)
    rp.hide_templates()
    rp.view(os.path.join(RAW, "check_elite.png"), 1400, 800, (0, 0, 1.3), 10, 10, 15, 28, True)
    rp.view(os.path.join(RAW, "check_elite_back.png"), 1400, 800, (0, 0, 1.3), 10, 35, 15, 28, False)


def _std(fn):
    rp.MODELS = V3
    fn()


def tiers():
    _std(rp.tiers)


def weapons():
    _std(rp.weapons_strip)


def zombies():
    _std(rp.zombies)


def lods():
    _std(rp.lods)


def lineup_v4():
    setup()
    rp.lane()
    # squad of 10, mixed tiers: front row tier a (pistol/rifle), middle tier b, back row tier c
    squad = [(-1.65, 0.0, "a", "wpn_pistol"), (-0.55, 0.0, "a", "wpn_rifle"), (0.55, 0.0, "b", "wpn_shotgun"),
             (1.65, 0.0, "a", "wpn_pistol"), (-1.1, 1.05, "b", "wpn_rifle"), (0.0, 1.05, "c", "wpn_gatling"),
             (1.1, 1.05, "b", "wpn_shotgun"), (-1.1, 2.1, "c", "wpn_rocket"), (0.0, 2.1, "b", "wpn_rifle"),
             (1.1, 2.1, "c", "wpn_gatling")]
    for x, y, t, w in squad:
        jx = 0.05 * math.sin(x * 7 + y * 3)
        rp.instance("chr_soldier_" + t, x + jx, y, 0)
        rp.instance(w, x + jx, y, 0)
        rp.blob(x + jx, y + 0.05, 0.48)
    for x, y, r in [(-1.4, 5.2, 12), (0.25, 4.9, -8), (1.7, 5.4, -15), (-0.5, 5.8, 6)]:
        rp.instance("enm_runner", x, y, 180 + r)
        rp.blob(x, y, 0.42)
    for x, y, r in [(-2.0, 6.9, 8), (-0.85, 7.1, -6), (0.9, 6.9, 10), (2.0, 7.2, -12), (-1.5, 8.2, 4),
                    (1.5, 8.3, -4)]:
        rp.instance("enm_walker", x, y, 180 + r)
        rp.blob(x, y - 0.05, 0.55)
    # far rank uses LOD1 as the game would
    for x, y, r in [(-2.2, 10.6, 5), (-0.9, 11.0, -8), (0.9, 10.8, 8), (2.2, 11.2, -5)]:
        rp.instance("enm_walker_lod1", x, y, 180 + r)
        rp.blob(x, y - 0.05, 0.55)
    rp.instance("enm_elite_brute", 0.05, 9.2, 180)
    rp.blob(0.05, 9.1, 1.2)
    rp.hide_templates()
    rp.camera((0, 4.6, 0.5), 11.8, 50, 0, 50)
    bpy.context.scene.cycles.samples = 48
    rp.render(os.path.join(RAW, "lineup_v4.png"), 1080, 1350)


def _ba(models, out, suffix):
    setup()
    rp.MODELS = models
    for x, body, wpn in ((3.1, "chr_soldier_a", "wpn_pistol"), (2.05, "chr_soldier_b", "wpn_rifle"),
                         (1.0, "chr_soldier_c", "wpn_gatling")):
        rp.instance(body, x, 0, 0)
        rp.instance(wpn, x, 0, 0)
        rp.blob(x, 0.05, 0.48)
    for x, n in ((-0.15, "enm_walker"), (-1.2, "enm_runner"), (-2.75, "enm_elite_brute")):
        rp.instance(n, x, 0, 0)
        rp.blob(x, 0.0, 0.5 if "elite" not in n else 1.05)
    rp.hide_templates()
    rp.view(os.path.join(RAW, out), 1800, 760, (0.15, 0, 1.0), 11.0, 12, 22, 23, True)


def beforeafter():
    _ba(V2, "ba_v2.png", "v2")
    _ba(V3, "ba_v3.png", "v3")


def load_boss():
    """Import boss_mutant.glb (body + weakpoint objects); preview glow on mat_weakpoint; join into one template."""
    if "boss_mutant" in rp._cache:
        return rp._cache["boss_mutant"]
    bpy.ops.import_scene.gltf(filepath=os.path.join(V3, "boss_mutant.glb"))
    obs = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    for o in obs:
        for m in o.data.materials:
            if m and m.name.startswith("mat_weakpoint"):
                nt = m.node_tree
                bsdf = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
                tex = [n for n in nt.nodes if n.type == "TEX_IMAGE"][0]
                nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
                bsdf.inputs["Emission Strength"].default_value = 0.9   # preview of the engine glow
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    rp._cache["boss_mutant"] = ob
    return ob


def boss_inst(x, y, rz=0.0):
    load_boss()
    return rp.instance("boss_mutant", x, y, rz)


def boss_views():
    setup()
    boss_inst(0, 0, 0)
    rp.blob(0.3, 0.2, 2.6)
    rp.hide_templates()
    # 3/4 front
    rp.view(os.path.join(RAW, "boss_front.png"), 1400, 1300, (0.4, 0, 2.5), 17, 12, 30, 26, True)
    # game camera close-up: from in front and above (the squad's camera looks at the boss's front/top)
    rp.view(os.path.join(RAW, "boss_weak.png"), 1000, 900, (0.3, 0, 3.4), 12, 55, 0, 30, True)
    # back (check only)
    rp.view(os.path.join(RAW, "boss_back.png"), 1000, 900, (0.3, 0, 2.6), 16, 25, 30, 28, False)


def boss_game():
    """game camera: squad of 10 at the bottom, boss 12 m in front, an elite beside it (portrait 1080x1920)."""
    setup()
    rp.lane()
    squad = [(-1.65, 0.0, "a", "wpn_pistol"), (-0.55, 0.0, "a", "wpn_rifle"), (0.55, 0.0, "b", "wpn_shotgun"),
             (1.65, 0.0, "a", "wpn_pistol"), (-1.1, 1.05, "b", "wpn_rifle"), (0.0, 1.05, "c", "wpn_gatling"),
             (1.1, 1.05, "b", "wpn_shotgun"), (-1.1, 2.1, "c", "wpn_rocket"), (0.0, 2.1, "b", "wpn_rifle"),
             (1.1, 2.1, "c", "wpn_gatling")]
    for x, y, t, w in squad:
        rp.instance("chr_soldier_" + t, x, y, 0)
        rp.instance(w, x, y, 0)
        rp.blob(x, y + 0.05, 0.48)
    by = 1.05 + 12.0
    boss_inst(0.0, by, 180)
    rp.blob(-0.3, by - 0.2, 2.6)
    rp.instance("enm_elite_brute", 2.6, by - 2.5, 180 + 15)
    rp.blob(2.6, by - 2.6, 1.2)
    rp.hide_templates()
    # same rig as the lineup but framed on the boss arena, portrait 9:16, FOV 50 vertical
    rp.camera((0, 7.6, 1.2), 18.5, 50, 0, 50)
    bpy.context.scene.cycles.samples = 40
    rp.render(os.path.join(RAW, "boss_game.png"), 1080, 1920)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for j in argv:
        globals()[j]()
