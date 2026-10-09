"""Render raw views for the third-party asset comparison (docs/art/research/asset_compare.png).
Usage: blender -b --factory-startup -P tools/art/research/render_compare.py -- [set ...]
Writes docs/art/research/_raw/<set>_{close,gun,game}.png ; compose_compare.py builds the final sheet.
Each set keeps its own textures/materials. Characters are posed with one frame of their own animation
and normalised to a common height so the sets can be compared side by side."""
import math, os, sys
import bpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
import render_previews as rp  # noqa: E402

TP = os.path.join(ROOT, "research", "third_party")
RAW = os.path.join(ROOT, "docs", "art", "research", "_raw")
os.makedirs(RAW, exist_ok=True)
KG = "Models/GLB format"
KK_ADV = os.path.join(TP, "kaykit/KayKit-Character-Pack-Adventures-1.0-main/addons/kaykit_character_pack_adventures")
KK_SKL = os.path.join(TP, "kaykit/KayKit-Character-Pack-Skeletons-1.0-main/addons/kaykit_character_pack_skeletons")

# soldier/zombie: (file, anim track, frame offset, meshes to keep (None = all), height m)
SETS = {
    "v2": dict(
        soldier=(os.path.join(ROOT, "assets/models/chr_soldier_b.glb"), None, 0, None, None),
        soldier_wpn=os.path.join(ROOT, "assets/models/wpn_rifle.glb"),
        zombie=(os.path.join(ROOT, "assets/models/enm_walker.glb"), None, 0, None, None),
        gun=os.path.join(ROOT, "assets/models/wpn_rifle.glb"), rot=0),
    "kenney": dict(
        soldier=(os.path.join(TP, "kenney/mini-characters", KG, "character-male-c.glb"), "holding-both-shoot", 4, None, 1.55),
        soldier_hand_gun=os.path.join(TP, "kenney/blaster-kit", KG, "blaster-d.glb"),
        zombie=(os.path.join(TP, "kenney/graveyard-kit", KG, "character-zombie.glb"), "walk", 6, None, 1.65),
        gun=os.path.join(TP, "kenney/blaster-kit", KG, "blaster-d.glb"), rot=180, gun_rot=180),
    "kaykit": dict(
        soldier=(os.path.join(KK_ADV, "Characters/gltf/Rogue.glb"), "2H_Ranged_Aiming", 10,
                 ["Rogue_ArmLeft", "Rogue_ArmRight", "Rogue_Body", "Rogue_Head", "Rogue_LegLeft", "Rogue_LegRight",
                  "Rogue_Cape", "2H_Crossbow"], 1.6),
        zombie=(os.path.join(KK_SKL, "Characters/gltf/Skeleton_Minion.glb"), "Walking_D_Skeletons", 8, None, 1.7),
        gun=os.path.join(KK_ADV, "Assets/gltf/crossbow_2handed.gltf"), rot=180),
    "quaternius": dict(
        soldier=(os.path.join(TP, "quaternius/toon_shooter_game_kit_polypizza/Character_Soldier.glb"), "Idle_Shoot", 6,
                 ["Head", "ShoulderPad.L", "ShoulderPad.R", "Body", "AK"], 1.6),
        zombie=(os.path.join(TP, "quaternius/zombie_apocalypse_kit_polypizza/Zombie_A.glb"), "Walk", 8,
                ["Zombie", "Eyelid"], 1.7),
        gun=os.path.join(TP, "quaternius/toon_shooter_game_kit_polypizza/AK47.glb"), rot=180),
}


def import_into(path, cname):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    col = bpy.data.collections.new(cname)
    bpy.context.scene.collection.children.link(col)
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)
    return col, new


def pose(objs, anim, frame_off):
    if not anim:
        return
    for o in objs:
        ad = o.animation_data
        if not ad:
            continue
        act = None
        for t in ad.nla_tracks:
            if t.name == anim and t.strips:
                act = t.strips[0].action
        for t in ad.nla_tracks:
            t.mute = True
        ad.action = act
    bpy.context.scene.frame_set(1 + frame_off)


def visible_meshes(objs):
    return [o for o in objs if o.type == "MESH" and not o.hide_render]


def bbox(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in visible_meshes(objs):
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        pts += [mw @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi


def prep_char(spec, cname, extra_gun=None):
    path, anim, foff, keep, height = spec
    col, objs = import_into(path, cname)
    for o in objs:
        if o.type == "MESH" and (o.name.startswith("Icosphere") or (keep is not None and o.name not in keep)):
            o.hide_render = True
    pose(objs, anim, foff)
    if extra_gun:  # Kenney: blaster held in front of the hands (no hand slot in the rig)
        lo, hi = bbox(objs)
        gcol, gobjs = import_into(extra_gun, cname + "_gun")
        # scale gun to ~45% of the (unscaled) body height, muzzle towards the facing direction (-Y)
        glo, ghi = bbox(gobjs)
        gl = max(ghi.x - glo.x, ghi.y - glo.y)
        k = 0.6 * (hi.z - lo.z) / gl
        for g in gobjs:
            if g.parent is None:
                g.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(k, 4) @ g.matrix_world
        glo, ghi = bbox(gobjs)
        gc = (glo + ghi) / 2
        # move gun objects into char collection, put grip at chest height in front of the body (-Y = facing)
        for g in gobjs:
            gcol.objects.unlink(g)
            col.objects.link(g)
            if g.parent is None:
                g.matrix_world = Matrix.Translation(Vector(((lo.x + hi.x) / 2 - 0.02, lo.y - 0.12, lo.z + (hi.z - lo.z) * 0.36)) - gc) @ g.matrix_world
        bpy.data.collections.remove(gcol)
        objs += gobjs
    lo, hi = bbox(objs)
    s = 1.0 if height is None else height / (hi.z - lo.z)
    col.instance_offset = ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z)
    bpy.context.view_layer.layer_collection.children[col.name].exclude = True
    return col, s


def inst(col, s, x, y, rot):
    e = bpy.data.objects.new(col.name + "_i", None)
    e.instance_type = "COLLECTION"
    e.instance_collection = col
    e.location = (x, y, 0)
    e.scale = (s, s, s)
    e.rotation_euler = (0, 0, math.radians(rot))
    bpy.context.scene.collection.objects.link(e)
    return e


def scene_base():
    rp.setup_scene()
    sc = bpy.context.scene
    sc.cycles.samples = 24
    sc.cycles.max_bounces = 2
    return sc


def render_set(name):
    d = SETS[name]
    rot = d["rot"]
    # --- close-up: soldier + zombie at 3/4 front
    scene_base()
    sol, ss = prep_char(d["soldier"], name + "_sol", d.get("soldier_hand_gun"))
    zom, zs = prep_char(d["zombie"], name + "_zom")
    if d.get("soldier_wpn"):
        wcol, wobjs = import_into(d["soldier_wpn"], name + "_wpn")
        for o in wobjs:
            wcol.objects.unlink(o)
            sol.objects.link(o)
        bpy.data.collections.remove(wcol)
    inst(sol, ss, 0.62, 0, rot + 0)
    inst(zom, zs, -0.62, 0, rot + 0)
    rp.blob(0.62, 0.05, 0.5)
    rp.blob(-0.62, 0.0, 0.55)
    rp.view(os.path.join(RAW, name + "_close.png"), 800, 760, (0, 0, 0.84), 7.4, 12, 28, 23, True)
    # --- gun alone, long axis across the screen
    scene_base()
    gcol, gobjs = import_into(d["gun"], name + "_gun")
    for o in gobjs:
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            o.hide_render = True
    lo, hi = bbox(gobjs)
    ext = hi - lo
    long_is_x = ext.x >= ext.y
    gcol.instance_offset = (lo + hi) / 2
    bpy.context.view_layer.layer_collection.children[gcol.name].exclude = True
    L = max(ext.x, ext.y)
    e = inst(gcol, 1.0 / L, 0, 0, (0 if long_is_x else 90) + d.get("gun_rot", 0))
    e.location = (0, 0, 0.6)
    # point the muzzle to screen-right: muzzle end is the end farther from the bbox centre of mass guess -> keep as is
    rp.view(os.path.join(RAW, name + "_gun.png"), 800, 300, (0, 0, 0.6), 4.2, 14, 22, 9.5, True)
    # --- game camera: squad of 6 behind, 5 zombies ahead, camera behind-and-above
    scene_base()
    rp.lane(width=7.5, y0=-6, y1=30)
    sol, ss = prep_char(d["soldier"], name + "_sol", d.get("soldier_hand_gun"))
    zom, zs = prep_char(d["zombie"], name + "_zom")
    if d.get("soldier_wpn"):
        wcol, wobjs = import_into(d["soldier_wpn"], name + "_wpn")
        for o in wobjs:
            wcol.objects.unlink(o)
            sol.objects.link(o)
        bpy.data.collections.remove(wcol)
    for x, y in ((-1.1, 0), (0, 0), (1.1, 0), (-0.55, 1.0), (0.55, 1.0), (-1.65, 1.0), (1.65, 1.0)):
        inst(sol, ss, x, y, rot + 0)
        rp.blob(x, y + 0.05, 0.45)
    for x, y, r in ((-1.5, 4.6, 10), (0.0, 4.4, -6), (1.4, 4.8, -12), (-0.7, 5.6, 5), (0.8, 5.7, -4), (2.2, 6.0, 8), (-2.1, 6.2, -8)):
        inst(zom, zs, x, y, rot + 180 + r)
        rp.blob(x, y, 0.5)
    rp.view(os.path.join(RAW, name + "_game.png"), 800, 900, (0, 2.7, 0.5), 8.4, 50, 0, 50, False)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for n in (argv or list(SETS)):
        render_set(n)
