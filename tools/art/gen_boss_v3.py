"""v3 Boss: boss_mutant (突变巨兽), Kenney-style bevelled blocky chibi, palette UVs only.

Usage (repo root):  blender -b --factory-startup -P tools/art/gen_boss_v3.py
Output: assets/models/boss_mutant.glb with TWO mesh objects (tech-lead request):
  - boss_mutant : body, material mat_palette
  - weakpoint   : glowing crystal cluster on the hump behind the neck, material mat_weakpoint
                  (same palette texture, orange / fire-yellow swatch UVs; the engine drives the glow)
Both share the origin (feet centre); authored Z up facing +Y -> glTF Y up facing -Z.
Style only (not derived from any Kenney mesh): chamfered boxes / tubes from blocky_lib, like the other v3 models.
Design refs: zombie-blaster-design/docs/design/enemies.md (Boss stops 12 m in front of the squad, smash / charge /
summon / acid rain, phases 60% / 25%, stun exposes the weak point), style-guide: 40-60% of screen width.
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lowpoly_lib as L  # noqa: E402
import blocky_lib as K  # noqa: E402
from blocky_lib import V, at, cbox, cprism, csweep, rect  # noqa: E402
from mathutils import Matrix  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PALETTE = os.path.join(ROOT, "assets", "textures", "palette.png")
OUT = os.path.join(ROOT, "assets", "models", "boss_mutant.glb")

FLESH, FLESH_D, BELLY = "rotpurple", "dkgreen", "cream"
MUT, MUT_D, BONE = "green", "dkgreen", "offwhite"
GLOW, GLOW_HI, GLOW_BASE = "orange", "fireyellow", "orangered"

# hunched torso frame: pivot at the hips, leaning toward the squad
MT = at((0, -0.1, 1.8), x=-22)


def body(B):
    # stubby legs, torn shorts, big feet with claws
    for s in (-1, 1):
        csweep(B, [(s * 0.72, -0.1, 1.45), (s * 0.86, 0.15, 0.80), (s * 0.86, 0.05, 0.36)],
               [(0.82, 0.82), (0.70, 0.70), (0.62, 0.62)], 0.12, ["ragbrown", FLESH], cap_top=False, cap_bot=False)
        cbox(B, (s * 0.86, 0.18, 0.21), (0.88, 1.12, 0.42), 0.11, FLESH, bevel=(False, True), cap_bot=False)
        for t in (-0.26, 0.0, 0.26):
            b = V((s * 0.86 + t, 0.72, 0.12))
            B.cone(b, b + V((0, 0.20, -0.04)), 0.08, BONE, n=4)
        rect(B, (s * 0.86, 0.15 + 0.31, 0.95), 0.30, 0.10, FLESH_D, M=at((0, 0, 0)))   # knee scar
    # pelvis + metal belt + loin flap
    cbox(B, (0, -0.1, 1.55), (2.05, 1.55, 0.72), 0.13, "ragbrown", bevel=(True, False), splits=(0.50,),
         side=lambda band, f: "metal" if band == 2 else None, top="metal")
    B.box((0, 0.72, 1.25), (0.80, 0.10, 0.60), "ragbrown", taper=(0.75, 1), rot=(10, 0, 0))
    rect(B, (0, 0.68, 1.79), 0.30, 0.18, "gold")
    # torso (pear shape) + cream belly + stitches
    cbox(B, (0, 0, 0.85), (2.60, 1.90, 1.70), 0.20, FLESH, M=MT, bevel=(False, True), splits=(0.30,),
         side=lambda band, f: FLESH_D if band == 0 and f in K.BACK else None, cap_bot=False)
    cbox(B, (0, 0.88, 0.62), (1.60, 0.30, 1.00), 0.08, BELLY, M=MT, bevel=(True, True))
    for z in (0.40, 0.62, 0.84):
        rect(B, (-0.25, 1.012, z), 0.42, 0.05, FLESH, M=MT, rot=0.15)
    # hump behind the neck (carries the weak point); rises above the head
    cbox(B, (0, -0.40, 1.95), (2.00, 1.45, 1.00), 0.22, FLESH, M=MT, bevel=(True, True), splits=(0.30,),
         side=lambda band, f: FLESH_D if band <= 1 else None, top=FLESH)
    # small bony ridge along the back below the hump
    for k, z in enumerate((1.25, 0.90, 0.55)):
        b = MT @ V((0, -0.95, z))
        B.cone(b, MT @ V((0, -1.25 + k * 0.04, z + 0.10)), 0.14 - k * 0.02, BONE, n=4)
    # head: sunk low in front of the hump, face lifted toward the squad
    MH = MT @ at((0, 0.82, 1.42), x=20)
    cprism(B, [(-0.40, 0.62, 0.52, 0.08), (-0.30, 0.70, 0.60, 0.12), (0.40, 0.70, 0.60, 0.12),
               (0.52, 0.58, 0.48, 0.08)], FLESH, M=MH, cap_bot=False,
           side=lambda band, f: FLESH_D if f in K.BACK else None)
    cbox(B, (0, 0.14, -0.55), (1.50, 1.20, 0.42), 0.12, FLESH, M=MH, bevel=(True, False), top=FLESH)  # jaw
    for x, h in ((-0.48, 0.30), (-0.16, 0.18), (0.16, 0.18), (0.48, 0.30)):                            # underbite
        B.cone(MH @ V((x, 0.62, -0.38)), MH @ V((x * 1.05, 0.66, -0.38 + h)), 0.08, BONE, n=4)
    ey = 0.60
    rect(B, (-0.30, ey, 0.12), 0.36, 0.34, "eyeyellow", M=MH)          # big eye
    rect(B, (-0.28, ey + 0.003, 0.10), 0.13, 0.15, "black", M=MH)
    rect(B, (-0.33, ey + 0.006, 0.17), 0.06, 0.06, "white", M=MH)
    rect(B, (0.32, ey, 0.10), 0.22, 0.20, "eyeyellow", M=MH)           # small eye
    rect(B, (0.33, ey + 0.003, 0.09), 0.08, 0.09, "black", M=MH)
    rect(B, (-0.28, ey + 0.004, 0.36), 0.46, 0.09, "black", M=MH, rot=-0.35)
    rect(B, (0.32, ey + 0.004, 0.30), 0.34, 0.08, "black", M=MH, rot=0.40)
    rect(B, (0, ey, -0.20), 0.70, 0.12, "black", M=MH)                 # mouth
    rect(B, (0.12, ey + 0.003, -0.24), 0.18, 0.08, "orangered", M=MH)  # tongue
    for x, tz in ((-0.38, 0.62), (0.40, 0.56)):                        # little bone horns
        B.cone(MH @ V((x, 0.05, 0.48)), MH @ V((x * 1.25, -0.05, 0.48 + tz * 0.5)), 0.10, BONE, n=4)
    # small left arm (-X): hangs low, small fist with claws
    sh = MT @ V((-1.30, 0.10, 1.25))
    el, wr = V((-1.85, 0.35, 1.70)), V((-1.80, 0.95, 1.25))
    csweep(B, [sh, el, wr], [(0.58, 0.58), (0.50, 0.50), (0.46, 0.46)], 0.09, FLESH, cap_bot=False, cap_top=False)
    fc = wr + V((0, 0.18, -0.22))
    cbox(B, tuple(fc), (0.62, 0.58, 0.56), 0.09, FLESH, bevel=(True, True))
    for t in (-0.18, 0.0, 0.18):
        b = fc + V((t, 0.29, -0.10))
        B.cone(b, b + V((0, 0.14, -0.06)), 0.05, BONE, n=4)
    # OVERSIZED mutant right arm (+X): green, huge shoulder mass, knuckles near the ground, bone spikes, shackle
    cbox(B, (1.42, -0.05, 1.30), (1.30, 1.55, 1.25), 0.20, MUT, M=MT, bevel=(True, True), splits=(0.35,),
         side=lambda band, f: MUT_D if band <= 1 else None)
    for k, (x, y, z) in enumerate(((1.45, -0.30, 1.95), (1.85, 0.10, 1.75), (1.30, 0.35, 1.95))):
        b = MT @ V((x, y, z - 0.05))
        B.cone(b, MT @ V((x * 1.08, y - 0.10, z + 0.45 - k * 0.08)), 0.14, BONE, n=4)
    sh = MT @ V((1.65, 0.05, 1.05))
    el, wr = V((2.20, 0.30, 1.55)), V((2.10, 1.10, 1.05))
    csweep(B, [sh, el, wr], [(1.00, 1.00), (0.92, 0.92), (1.12, 1.12)], 0.16, [MUT, MUT], cap_bot=False,
           cap_top=False)
    # forearm bulge + veins + spikes
    mid = el + (wr - el) * 0.55
    csweep(B, [el + (wr - el) * 0.25, mid, wr + (wr - el) * 0.02], [(1.06, 1.06), (1.26, 1.26), (1.14, 1.14)],
           0.18, [MUT, MUT], caps=(MUT, MUT))
    for k, t in enumerate((0.35, 0.60)):
        b = el + (wr - el) * t + V((0.50, -0.05, 0.25))
        B.cone(b, b + V((0.40, -0.12, 0.25)), 0.12, BONE, n=4)
    csweep(B, [wr + (wr - el) * 0.02, wr + (wr - el) * 0.16], [(1.22, 1.22), (1.22, 1.22)], 0.16, "metal",
           caps=("asphalt", "asphalt"))                                     # shackle
    for k in range(2):                                                      # broken chain links
        B.box(tuple(wr + V((-0.62 - k * 0.20, -0.10, -0.25 - k * 0.22))), (0.10, 0.22, 0.26), "asphalt",
              rot=(0, 0, 90 * k))
    fc = V((2.08, 1.33, 0.62))
    cbox(B, tuple(fc), (1.42, 1.30, 1.24), 0.18, MUT_D, bevel=(True, True), splits=(0.30,),
         side=lambda band, f: MUT if band >= 2 else None, top=MUT)
    for t in (-0.42, -0.14, 0.14, 0.42):                                    # knuckle studs
        b = fc + V((t, 0.64, 0.30))
        B.cone(b, b + V((0, 0.16, 0.02)), 0.07, BONE, n=4)


def weakpoint(B):
    """Glowing crystal cluster + pustule pad on top of the hump (visible from the front-above game camera)."""
    top = 1.95 + 0.50
    cbox(B, (0, -0.40, top + 0.06), (1.55, 1.05, 0.14), 0.10, GLOW_BASE, M=MT, bevel=(False, True), cap_bot=False,
         top=GLOW)
    cryst = [(0.00, -0.35, 0.30, 1.25, 0, 0), (-0.42, -0.25, 0.22, 0.85, -14, 8), (0.42, -0.28, 0.22, 0.90, 14, 6),
             (-0.20, -0.70, 0.18, 0.70, -8, -18), (0.24, -0.72, 0.18, 0.75, 8, -16), (-0.55, -0.62, 0.14, 0.50, -22, -10),
             (0.58, -0.58, 0.14, 0.55, 22, -8), (0.05, 0.02, 0.15, 0.50, 0, 22)]
    for x, y, r, h, ry, rx in cryst:
        M = MT @ Matrix.Translation(V((x, y, top + 0.10))) @ K.rotm(x=rx + 10, y=ry)
        p0, p1, p2 = M @ V((0, 0, -0.10)), M @ V((0, 0, h * 0.62)), M @ V((0, 0, h))
        B.sweep([p0, p1], [r, r * 0.9], GLOW, n=6, caps=(GLOW_BASE, GLOW))
        B.cone(p1, p2, r * 0.9, GLOW_HI, n=6)
    for x, y in ((-0.70, -0.05), (0.72, -0.10), (-0.05, -0.95), (0.75, -0.85)):  # pustules on the pad edge
        c = MT @ V((x, y, top + 0.10))
        B.blob(tuple(c), (0.16, 0.16, 0.12), GLOW_HI, n=6, lats=(-30, 30, 75))


def weak_material(palette_path):
    m = L.palette_material(palette_path).copy()
    m.name = "mat_weakpoint"
    return m


def main():
    L.reset_scene()
    mat = L.palette_material(PALETTE)
    wmat = weak_material(PALETTE)
    obs = []
    for name, fn, m in (("boss_mutant", body, mat), ("weakpoint", weakpoint, wmat)):
        B = L.Builder()
        fn(B)
        obs.append((B, name, m))
    dz = min(min(v.z for v in B.verts) for B, _, _ in obs)
    assert abs(dz) < 0.03, dz
    made = []
    for B, name, m in obs:
        B.verts = [v - V((0, 0, dz)) for v in B.verts]
        made.append(B.build(name, m))
    bpy.ops.object.select_all(action="DESELECT")
    for ob in made:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
        export_normals=True, export_texcoords=True, export_materials="EXPORT", export_image_format="AUTO",
        export_animations=False, export_skins=False, export_morph=False, export_attributes=False)
    xs = [v.co.x for ob in made for v in ob.data.vertices]
    ys = [v.co.y for ob in made for v in ob.data.vertices]
    zs = [v.co.z for ob in made for v in ob.data.vertices]
    print("EXPORTED boss_mutant  body %d + weakpoint %d = %d tris  x %.2f..%.2f  fwd %.2f back %.2f  h %.2f" % (
        len(made[0].data.polygons), len(made[1].data.polygons),
        sum(len(o.data.polygons) for o in made), min(xs), max(xs), max(ys), -min(ys), max(zs)))


main()
