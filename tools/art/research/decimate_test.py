"""Quick check: can Kenney models reach our budgets with Blender Decimate (collapse)?
Renders docs/art/research/_raw/kenney_decimate.png (top: original, bottom: decimated) and prints tri counts.
Usage: blender -b --factory-startup -P tools/art/research/decimate_test.py"""
import math, os, sys
import bpy
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
import render_previews as rp  # noqa
import render_compare as rc  # noqa
KG = "Models/GLB format"
TP = rc.TP
ITEMS = [("soldier", os.path.join(TP, "kenney/mini-characters", KG, "character-male-c.glb"), "holding-both-shoot", 450),
         ("zombie", os.path.join(TP, "kenney/graveyard-kit", KG, "character-zombie.glb"), "walk", 450),
         ("zombie_lod", os.path.join(TP, "kenney/graveyard-kit", KG, "character-zombie.glb"), "walk", 200),
         ("gun", os.path.join(TP, "kenney/blaster-kit", KG, "blaster-d.glb"), None, 120)]


def tris(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    t = 0
    for o in objs:
        if o.type == "MESH" and not o.hide_render:
            me = o.evaluated_get(dg).to_mesh(); t += sum(len(p.vertices) - 2 for p in me.polygons); o.evaluated_get(dg).to_mesh_clear()
    return t


rp.setup_scene(); bpy.context.scene.cycles.samples = 24
x = 2.4
for k, (nm, path, anim, target) in enumerate(ITEMS):
    for row, dec in ((0, False), (1, True)):
        col, objs = rc.import_into(path, f"{nm}_{row}")
        for o in objs:
            if o.type == "MESH" and o.name.startswith("Icosphere"):
                o.hide_render = True
        t0 = tris(objs)
        if dec:
            ratio = target / t0
            for o in objs:
                if o.type == "MESH" and not o.hide_render:
                    m = o.modifiers.new("dec", "DECIMATE"); m.ratio = ratio
                    # keep decimate before the armature deform
                    while o.modifiers.find("dec") > 0:
                        bpy.context.view_layer.objects.active = o
                        bpy.ops.object.modifier_move_up(modifier="dec")
        rc.pose(objs, anim, 4)
        t1 = tris(objs)
        print("DEC", nm, "row", row, "tris", t1, "(orig %d, target %d)" % (t0, target))
        lo, hi = rc.bbox(objs)
        h = 1.0 if nm == "gun" else 1.55
        s = (0.9 / max(hi.x - lo.x, hi.y - lo.y)) if nm == "gun" else h / (hi.z - lo.z)
        col.instance_offset = ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z)
        bpy.context.view_layer.layer_collection.children[col.name].exclude = True
        e = rc.inst(col, s, x - k * 1.6, 0, 180 if nm != "gun" else 90)
        e.location.z = (0.5 if nm == "gun" else 0) + (0 if row == 0 else -2.0) + 2.0
rp.view(os.path.join(rc.RAW, "kenney_decimate.png"), 1400, 900, (0, 0, 1.9), 9.5, 8, 0, 30, True)
