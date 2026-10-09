"""v3 characters + weapons: Kenney-style bevelled blocky chibi, palette UVs only.

Usage (repo root):
  blender -b --factory-startup -P tools/art/gen_characters_v3.py [-- name1 name2 ...]
Outputs assets/models/*.glb (v2 is kept in assets/models/_v2/, generator tools/art/gen_characters.py).

Derived from Kenney (CC0, www.kenney.nl): the soldiers are rebuilt part by part over Kenney Mini Characters
"character-male-c" (proportions x2.1, part layout, face layout, cap + brim), the zombies over Kenney Graveyard
Kit "character-zombie" (x2.0; square head, flat-top hair with tufts, big square eyes, ears, teeth). Kenney's
meshes are 700-1100 tris with a gradient colormap, so every part was re-modelled as a chamfered box/tube with
flat palette colours instead of decimating (Decimate broke faces and UVs, see docs/art/research/).
Authored in metres, Blender space (Z up, faces +Y, origin between the feet); glTF export -> Y up, facing -Z.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lowpoly_lib as L  # noqa: E402
import blocky_lib as K  # noqa: E402
from blocky_lib import V, at, cbox, cprism, csweep, rect, BACK, SIDES  # noqa: E402
from blocky_lib import F_F, F_FR, F_FL, F_R, F_L, F_B, F_BL, F_BR  # noqa: E402
from mathutils import Matrix  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PALETTE = os.path.join(ROOT, "assets", "textures", "palette.png")
OUT = os.path.join(ROOT, "assets", "models")

# ----------------------------------------------------------------------------- shared soldier pose
# v2 hand/weapon frame (the wpn_* builders below are authored in it) and the v3 offset.
RH2, LH2 = V((0.11, 0.20, 0.70)), V((-0.02, 0.36, 0.735))
GX, GZ = 0.055, 0.775
# v3 hands sit lower (shorter Kenney torso), further forward and to the right: the big chibi head would hide a
# centred gun from the behind-and-above game camera, so the squad aims from the right hip (gun axis x ~ +0.33 m).
DELTA = V((0.27, 0.14, -0.20))
RH, LH = RH2 + DELTA, LH2 + DELTA       # (0.38, 0.34, 0.50), (0.25, 0.50, 0.535)
# Kenney's chibi at x2.1 is ~1.5 m; the whole soldier rig (incl. weapons, so offset 0 still fits) is scaled up.
SOLDIER_S = 1.07
SCALE = {"chr_soldier_a": SOLDIER_S, "chr_soldier_b": SOLDIER_S, "chr_soldier_c": SOLDIER_S,
         "enm_walker": 1.10, "enm_walker_lod1": 1.10, "enm_runner": 1.08, "enm_runner_lod1": 1.08}
WPN_SCALE = {"wpn_pistol": 1.45, "wpn_rifle": 1.3, "wpn_shotgun": 1.3, "wpn_gatling": 1.35, "wpn_rocket": 1.25}

HEAD_Z0, HEAD_HX, HEAD_HY, HEAD_C = 0.72, 0.335, 0.32, 0.06
FACE_Y = HEAD_HY


def soldier_head(B, tier):
    hx, hy, c, z0 = HEAD_HX, HEAD_HY, HEAD_C, HEAD_Z0
    hair = "ragbrown"
    # top ring hidden inside the cap/helmet -> no caps (bottom sits inside the torso collar)
    rings = [(z0, hx - c, hy - c, c * 0.5), (z0 + c, hx, hy, c), (1.00, hx, hy, c), (1.26, hx, hy, c)]

    def side(band, f):
        if band == 0:
            return hair if f in BACK else "skin"
        if band == 1:
            return hair if f in BACK else "skin"
        return hair if f in BACK + SIDES else "skin"
    cprism(B, rings, "skin", side=side, cap_top=False, cap_bot=False)
    # ears (Kenney: small blocks low on the sides)
    for s in (-1, 1):
        B.box((s * (hx + 0.03), -0.02, 0.95), (0.07, 0.13, 0.16), "skin")
    # face: tall dark eyes with a highlight, short brows, small mouth
    y = FACE_Y
    for s in (-1, 1):
        rect(B, (s * 0.145, y, 1.01), 0.10, 0.12, "black")
        rect(B, (s * 0.145 - 0.022, y + 0.002, 1.04), 0.035, 0.035, "white")
        rect(B, (s * 0.15, y, 1.12), 0.12, 0.035, hair if tier == "a" else "navy",
             rot=(-0.12 if tier == "a" else 0.18) * s)
    rect(B, (0, y, 0.865), 0.09 if tier == "a" else 0.07, 0.03, "black")


def soldier(B, tier="a"):
    # legs: tapered boot band + trouser band (tops hidden in the torso, soles on the ground)
    for s in (-1, 1):
        x = s * 0.135
        cprism(B, [(0.0, 0.13, 0.17, 0.04, x, 0.035), (0.15, 0.115, 0.13, 0.04, x, 0.0),
                   (0.42, 0.115, 0.13, 0.04, x, 0.0)], "navy",
               side=lambda band, f: "black" if band == 0 else None, cap_top=False, cap_bot=False)
    # torso: belt band + shirt / vest / armour, shoulder chamfer
    tcol = {"a": ("gear", "blue", "blue"), "b": ("gear", "gear", "blue"), "c": ("gold", "lightblue", "navy")}[tier]
    cbox(B, (0, 0, 0.555), (0.54, 0.42, 0.37), 0.05, "blue", bevel=(False, True), splits=(0.08,),
         side=lambda band, f: tcol[band], top=tcol[2], cap_bot=False)
    if tier == "a":
        rect(B, (0, 0.21, 0.41), 0.08, 0.05, "gold")                                         # buckle
    elif tier == "b":
        B.box((0.0, 0.225, 0.55), (0.30, 0.06, 0.14), "navy")                              # vest pouches
        cbox(B, (0, -0.27, 0.57), (0.36, 0.14, 0.30), 0.04, "sand", bevel=(False, False), top="ragbrown")  # pack
    else:
        rect(B, (0, 0.214, 0.57), 0.14, 0.14, "gold")                                      # chest emblem
        cbox(B, (0, -0.28, 0.58), (0.38, 0.16, 0.32), 0.04, "navy", bevel=(False, False), top="gold")  # power pack
        for s in (-1, 1):                                                                  # shoulder plates
            B.box((s * 0.30, 0.0, 0.73), (0.20, 0.30, 0.09), "gold", taper=(0.8, 0.8), top="lightblue")
    soldier_head(B, tier)
    # headgear: the readable tier marker from the behind-and-above camera
    if tier == "a":   # cap: blue crown, navy brim, gold badge
        cbox(B, (0, -0.01, 1.36), (0.72, 0.70, 0.30), 0.06, "blue", bevel=(False, True), top="blue")
        B.box((0, 0.42, 1.235), (0.58, 0.22, 0.035), "navy", rot=(-8, 0, 0))
        rect(B, (0, 0.344, 1.37), 0.08, 0.09, "gold")
    else:             # helmet: b = teal top, c = gold rim + gold top + crest
        hc = {"b": ("navy", "dkteal", "teal", "teal"), "c": ("gold", "blue", "gold", "gold")}[tier]
        cbox(B, (0, -0.01, 1.33), (0.76, 0.74, 0.40), 0.09, "navy", bevel=(False, True), splits=(0.10,),
             side=lambda band, f: hc[band], top=hc[3])
        if tier == "b":   # goggles on the rim
            rect(B, (0, 0.364, 1.18), 0.56, 0.06, "black")
            for s in (-1, 1):
                rect(B, (s * 0.12, 0.367, 1.18), 0.14, 0.09, "lightblue")
        else:             # crest fin + visor
            B.box((0, -0.03, 1.545), (0.08, 0.46, 0.07), "gold", taper=(0.7, 0.8))
            rect(B, (0, 0.364, 1.23), 0.40, 0.07, "lightblue")
    # arms in the shared two-handed aim pose + block hands
    sleeve = "blue" if tier != "c" else "navy"
    hand = "skin" if tier != "c" else "navy"
    for sh, el, wr, hp in (((0.29, 0.02, 0.66), (0.40, 0.14, 0.50), (0.385, 0.27, 0.50), RH),
                           ((-0.29, 0.02, 0.66), (-0.17, 0.29, 0.55), (0.18, 0.46, 0.535), LH)):
        csweep(B, [sh, el, wr], [(0.15, 0.15), (0.14, 0.14), (0.13, 0.13)], 0.03, sleeve, cap_top=False)
        B.box(tuple(hp), (0.14, 0.14, 0.14), hand)


# ----------------------------------------------------------------------------- weapons (v2 shapes, chunkier)
def pistol(B):
    x, z = GX, GZ
    B.box((x, 0.27, z + 0.01), (0.065, 0.25, 0.075), "black", top="gear")
    B.box((x, 0.25, z - 0.035), (0.06, 0.21, 0.04), "gear")
    B.box((x, 0.195, z - 0.09), (0.055, 0.065, 0.13), "black", rot=(18, 0, 0))
    B.box((x, 0.27, z - 0.07), (0.03, 0.06, 0.02), "black")
    B.box((x, 0.41, z + 0.012), (0.04, 0.05, 0.04), "metal")


def rifle(B):
    x, z = GX, GZ
    B.box((x, 0.0, z - 0.015), (0.065, 0.20, 0.11), "black", taper=(1, 0.85))
    B.box((x, 0.20, z), (0.08, 0.26, 0.105), "gear", top="metal")
    B.box((x, 0.25, z - 0.11), (0.055, 0.07, 0.15), "black", rot=(-12, 0, 0))
    B.box((x, 0.165, z - 0.08), (0.05, 0.05, 0.09), "black", rot=(20, 0, 0))
    B.box((x, 0.42, z + 0.005), (0.085, 0.18, 0.09), "navy")
    B.box((x, 0.21, z + 0.07), (0.035, 0.10, 0.035), "black")
    B.sweep([(x, 0.51, z + 0.01), (x, 0.72, z + 0.01)], [0.024, 0.024], "metal", n=4)
    B.box((x, 0.745, z + 0.01), (0.06, 0.05, 0.06), "black")


def shotgun(B):
    x, z = GX, GZ
    B.box((x, 0.0, z - 0.02), (0.07, 0.22, 0.115), "navy", taper=(1, 0.85))
    B.box((x, 0.20, z), (0.085, 0.24, 0.115), "black", top="gear")
    B.box((x + 0.045, 0.20, z), (0.008, 0.15, 0.06), "gold")
    B.box((x, 0.165, z - 0.085), (0.055, 0.055, 0.10), "black", rot=(20, 0, 0))
    B.sweep([(x, 0.32, z + 0.025), (x, 0.80, z + 0.025)], [0.034, 0.034], "metal", n=4)
    B.sweep([(x, 0.32, z - 0.03), (x, 0.74, z - 0.03)], [0.028, 0.028], "black", n=4)
    B.box((x, 0.53, z - 0.03), (0.10, 0.18, 0.08), "navy")
    B.box((x, 0.81, z + 0.025), (0.08, 0.04, 0.08), "gold")


def gatling(B):
    x, z = GX, GZ - 0.02
    csweep(B, [(x, 0.06, z), (x, 0.12, z), (x, 0.36, z)], [(0.15, 0.15), (0.19, 0.19), (0.18, 0.18)], 0.04,
           ["gold", "navy"], caps=("black", "metal"))
    for k in range(3):
        a = math.pi / 2 + k * 2 * math.pi / 3
        ox, oz = 0.045 * math.cos(a), 0.045 * math.sin(a)
        B.sweep([(x + ox, 0.36, z + oz), (x + ox, 0.84, z + oz)], [0.022, 0.022], "metal", n=4)
    B.box((x, 0.757, z), (0.15, 0.035, 0.15), "gold")
    B.box((x, 0.18, z - 0.10), (0.05, 0.06, 0.10), "black", rot=(15, 0, 0))
    B.box((x - 0.10, 0.22, z - 0.04), (0.10, 0.14, 0.12), "navy", top="gold")


def rocket(B):
    x, z = GX, GZ
    csweep(B, [(x, -0.32, z), (x, -0.26, z), (x, 0.50, z), (x, 0.56, z)],
           [(0.17, 0.17), (0.14, 0.14), (0.14, 0.14), (0.17, 0.17)], 0.035,
           ["gold", "blue", "gold"], caps=("black", "black"))
    B.cone((x, 0.56, z), (x, 0.74, z), 0.06, "orangered", n=4)
    B.box((x, 0.19, z - 0.10), (0.05, 0.06, 0.10), "black", rot=(15, 0, 0))
    B.box((x - 0.01, 0.36, z - 0.09), (0.05, 0.06, 0.09), "black", rot=(15, 0, 0))
    B.box((x + 0.09, 0.06, z + 0.05), (0.05, 0.12, 0.07), "gear", top="metal")


# ----------------------------------------------------------------------------- zombies
def pivot(t, p, x=0.0):
    """translate by t after rotating about point p (around X)."""
    return Matrix.Translation(V(t) + V(p)) @ K.rotm(x=x) @ Matrix.Translation(-V(p))


def zombie_head(B, M, hx, hy, z0, h, skin, skind, hair, lod=False, tufts=True, eye_s=1.0, face_kind="walker"):
    """Kenney graveyard-zombie head: square block, flat-top dark hair covering back/sides/top."""
    c = 0.06 if not lod else 0.045
    if not lod:
        rings = [(z0, hx - c, hy - c, c * 0.5), (z0 + c, hx, hy, c), (z0 + h * 0.52, hx, hy, c),
                 (z0 + h - c, hx, hy, c), (z0 + h, hx - c, hy - c, c * 0.5)]

        def side(band, f):
            if band == 0:
                return skind
            if band == 1:
                return hair if f in BACK else skin
            if band == 2:
                return skin if f in (F_F, F_FR, F_FL) else hair
            return hair
    else:
        rings = [(z0, hx, hy, c), (z0 + h * 0.52, hx, hy, c), (z0 + h, hx, hy, c)]

        def side(band, f):
            if band == 0:
                return hair if f in BACK else skin
            return skin if f == F_F else hair
    cprism(B, rings, skin, M=M, side=side, top=hair, cap_bot=False)
    y = hy
    zc = z0 + h * 0.47
    e = 0.13 * eye_s
    if face_kind == "walker":
        for s, dz in ((-1, 0.0), (1, 0.015)):
            rect(B, (s * 0.135, y, zc + dz), e, e, "orange", M=M)
            rect(B, (s * 0.135 + s * 0.02, y + 0.002, zc + dz - 0.025), 0.045, 0.045, "black", M=M)   # pupils low/out
            if not lod:
                rect(B, (s * 0.135, y + 0.003, zc + dz + e * 0.36), e * 1.08, e * 0.32, skind, M=M, rot=0.12 * s)
        rect(B, (0.0, y, z0 + h * 0.2), 0.20, 0.055, "black", M=M)
        if not lod:
            for tx in (-0.045, 0.04):
                rect(B, (tx, y + 0.002, z0 + h * 0.2 + 0.012), 0.035, 0.035, "offwhite", M=M)
    else:  # runner: wide crazy eyes, tongue
        for s in (-1, 1):
            rect(B, (s * 0.125, y, zc), e * 1.1, e * 1.1, "orange", M=M)
            rect(B, (s * 0.125, y + 0.002, zc), 0.04, 0.04, "black", M=M)
        rect(B, (0.0, y, z0 + h * 0.2), 0.20, 0.06, "black", M=M)
        rect(B, (0.035, y + 0.002, z0 + h * 0.2 - 0.03), 0.06, 0.07, "orangered", M=M)
    if not lod:
        B.box(tuple(M @ V((0, y + 0.03, zc - 0.07))), (0.07, 0.06, 0.08), skind)              # nose
        for s in (-1, 1):                                                                    # ears
            B.box(tuple(M @ V((s * (hx + 0.025), -0.01, zc))), (0.06, 0.11, 0.17), skin)
    if tufts and not lod:
        for tx, ty, hgt in ((-0.12, -0.05, 0.12), (0.02, 0.06, 0.15), (0.13, -0.08, 0.11)):
            b = M @ V((tx, ty, z0 + h - 0.02))
            B.cone(b, M @ V((tx * 1.15, ty - 0.03, z0 + h + hgt)), 0.06, hair, n=4)


def walker(B, lod=False):
    skin, skind, hair, shirt, pants = "green", "dkgreen", "asphalt", "cream", "ragbrown"
    # legs (slight stagger): shoe band + trouser band
    for s, dy in ((-1, 0.05), (1, -0.05)):
        x = s * 0.13
        if not lod:
            cprism(B, [(0.0, 0.12, 0.16, 0.035, x, dy + 0.03), (0.13, 0.11, 0.12, 0.035, x, dy),
                       (0.46, 0.115, 0.125, 0.035, x, 0.0)], pants,
                   side=lambda band, f: "black" if band == 0 else None, cap_top=False, cap_bot=False)
        else:
            B.sweep([(x, dy + 0.02, 0.0), (x, dy, 0.13), (x, 0.0, 0.46)], [(0.12, 0.14), (0.11, 0.12), (0.115, 0.125)],
                    ["black", pants], n=4, caps=("black", pants))
    lean = -10
    Mu = Matrix.Translation(V((0, 0, 0.42))) @ K.rotm(x=lean) @ Matrix.Translation(V((0, 0, -0.42)))
    # torso: trouser band + torn shirt
    cbox(B, (0, 0, 0.62), (0.52, 0.38, 0.40), 0.05 if not lod else 0.04, shirt, M=Mu,
         bevel=(False, not lod), splits=(0.08,), side=lambda band, f: pants if band == 0 else None,
         top=shirt, cap_bot=False)
    if not lod:
        rect(B, (0.06, 0.19, 0.66), 0.12, 0.09, "ltgreen", M=Mu)                               # belly rip
        rect(B, (-0.10, -0.19, 0.70), 0.11, 0.10, "rotpurple", normal=(0, -1, 0), M=Mu)       # rot patch
    # arms straight out in front (zombie reach), sleeves + green forearms + block hands
    for s in (-1, 1):
        sh, el, wr = (s * 0.30, 0.0, 0.78), (s * 0.31, 0.16, 0.77 + 0.02 * s), (s * 0.28, 0.29, 0.76 + 0.03 * s)
        P = [Mu @ V(p) for p in (sh, el, wr)]
        if not lod:
            csweep(B, P, [(0.15, 0.15), (0.13, 0.13), (0.12, 0.12)], 0.03, [shirt, skin], cap_top=False)
            hc = Mu @ V((s * 0.275, 0.36, 0.755 + 0.03 * s))
            B.box(tuple(hc), (0.15, 0.13, 0.13), skin, rot=(lean, 0, 0))
        else:
            hc = Mu @ V((s * 0.275, 0.38, 0.755 + 0.03 * s))
            B.sweep(P[:2] + [hc], [0.075, 0.068, 0.07], [shirt, skin], n=4)
    # head: big, pushed forward
    Mh = Mu @ pivot((0.0, 0.03, 0.0), (0, 0, 0.83), x=5)
    zombie_head(B, Mh, 0.31, 0.29, 0.83, 0.58, skin, skind, hair, lod=lod)


def runner(B, lod=False):
    skin, skind, hair, shirt, pants = "ltgreen", "green", "black", "rotpurple", "asphalt"
    # long stride: left leg forward, right leg back (thigh, shin, shoe)
    legs = (((-0.11, 0.0, 0.46), (-0.11, 0.16, 0.26), (-0.11, 0.10, 0.06)),
            ((0.11, 0.0, 0.46), (0.11, -0.13, 0.25), (0.11, -0.31, 0.17)))
    for k, (hip, kn, an) in enumerate(legs):
        if not lod:
            csweep(B, [hip, kn, an], [(0.20, 0.20), (0.18, 0.18), (0.16, 0.16)], 0.03, [pants, skin],
                   cap_top=False, cap_bot=False)
            if k == 0:
                cbox(B, (an[0], an[1] + 0.04, 0.055), (0.20, 0.28, 0.11), 0.03, "black", bevel=(False, False),
                     cap_bot=False)
            else:
                cbox(B, (an[0], an[1] - 0.04, an[2] - 0.03), (0.20, 0.27, 0.11), 0.03, "black",
                     M=at((0, 0, 0)) , bevel=(False, False))
        else:
            B.sweep([hip, kn, an], [0.10, 0.09, 0.08], [pants, skin], n=4)
            B.box((an[0], an[1] + (0.04 if k == 0 else -0.04), 0.055 if k == 0 else an[2] - 0.03),
                  (0.19, 0.26, 0.11), "black")
    lean = -24
    Mu = Matrix.Translation(V((0, 0, 0.44))) @ K.rotm(x=lean) @ Matrix.Translation(V((0, 0, -0.44)))
    cbox(B, (0, 0, 0.64), (0.42, 0.30, 0.40), 0.045 if not lod else 0.035, shirt, M=Mu,
         bevel=(False, not lod), splits=(0.07,), side=lambda band, f: pants if band == 0 else None,
         top=shirt, cap_bot=False)
    if not lod:
        rect(B, (-0.06, -0.153, 0.72), 0.10, 0.12, skin, normal=(0, -1, 0), M=Mu)            # rip on the back
        rect(B, (0.07, 0.153, 0.60), 0.08, 0.07, skind, M=Mu)
    # arms: right reaching forward, left swung back (running)
    arms = (((0.24, 0.0, 0.78), (0.27, 0.16, 0.66), (0.24, 0.27, 0.70), (0.235, 0.33, 0.715)),
            ((-0.24, 0.0, 0.78), (-0.27, -0.12, 0.62), (-0.25, -0.22, 0.70), (-0.245, -0.28, 0.73)))
    for sh, el, wr, hd in arms:
        P = [Mu @ V(p) for p in (sh, el, wr)]
        if not lod:
            csweep(B, P, [(0.12, 0.12), (0.11, 0.11), (0.10, 0.10)], 0.025, [shirt, skin], cap_top=False)
            B.box(tuple(Mu @ V(hd)), (0.12, 0.11, 0.11), skind, rot=(lean, 0, 0))
        else:
            B.sweep(P[:2] + [Mu @ V(hd) - V((0, 0.02, 0))], [0.06, 0.055, 0.06], [shirt, skin], n=4)
    Mh = Mu @ pivot((0.0, 0.0, 0.0), (0, 0, 0.84), x=12)     # head lifted back up while the body leans
    zombie_head(B, Mh, 0.28, 0.26, 0.84, 0.54, skin, skind, hair, lod=lod, eye_s=1.0, face_kind="runner")
    if not lod:   # hair swept back: two long spikes
        for tx in (-0.08, 0.08):
            b = Mh @ V((tx, -0.10, 1.36))
            B.cone(b, Mh @ V((tx * 1.3, -0.40, 1.44)), 0.06, hair, n=4)


def elite_brute(B):
    sk, skd, red, redd, met = "green", "dkgreen", "elitered", "bossred", "metal"
    # legs + feet + knee plates
    for s in (-1, 1):
        csweep(B, [(s * 0.36, -0.05, 1.10), (s * 0.40, 0.05, 0.55), (s * 0.40, 0.0, 0.16)],
               [(0.36, 0.36), (0.30, 0.30), (0.27, 0.27)], 0.05, ["ragbrown", skd], cap_top=False, cap_bot=False)
        cbox(B, (s * 0.40, 0.07, 0.10), (0.36, 0.50, 0.20), 0.05, skd, bevel=(False, True), cap_bot=False)
        for t in (-0.11, 0.0, 0.11):
            b = V((s * 0.40 + t, 0.30, 0.06))
            B.cone(b, b + V((0, 0.08, -0.02)), 0.035, "offwhite", n=3)
        cbox(B, (s * 0.41, 0.17, 0.60), (0.28, 0.12, 0.28), 0.04, red, bevel=(True, True), splits=(0.06,),
             side=lambda band, f: redd if band <= 1 else None)
    # pelvis + metal belt + loincloth
    cbox(B, (0, -0.02, 1.14), (0.96, 0.66, 0.32), 0.06, "ragbrown", bevel=(True, False), splits=(0.26,),
         side=lambda band, f: met if band == 2 else None, top=met)
    rect(B, (0, 0.31, 1.24), 0.16, 0.10, "gold")
    B.box((0, 0.33, 0.96), (0.40, 0.06, 0.34), "ragbrown", taper=(0.8, 1), rot=(8, 0, 0))
    # hunched torso
    Mt = at((0, 0, 1.24), x=-18)
    cbox(B, (0, 0, 0.50), (1.20, 0.80, 1.00), 0.12, sk, M=Mt, bevel=(False, True), splits=(0.18,),
         side=lambda band, f: "ltgreen" if band == 0 and f in (F_F, F_FR, F_FL) else None, top=sk, cap_bot=False)
    # chest armour + rivets
    cbox(B, (0, 0.41, 0.56), (0.92, 0.16, 0.62), 0.05, red, M=Mt, bevel=(True, True), splits=(0.08,),
         side=lambda band, f: redd if band <= 1 else None)
    for s in (-1, 1):
        B.box(tuple(Mt @ V((s * 0.30, 0.50, 0.74))), (0.07, 0.04, 0.07), met, rot=(-18, 0, 0))
    # back plate + spikes + rot wound
    cbox(B, (0, -0.42, 0.62), (0.80, 0.10, 0.62), 0.04, met, M=Mt, bevel=(True, True))
    for x, h in ((-0.24, 0.30), (0.0, 0.40), (0.24, 0.30)):
        b = Mt @ V((x, -0.46, 0.80))
        B.cone(b, Mt @ V((x * 1.2, -0.66, 0.80 + h)), 0.07, met, n=4)
    rect(B, (-0.36, -0.405, 0.16), 0.14, 0.12, "rotpurple", normal=(0, -1, 0), M=Mt)
    # head sunk between the shoulders: jaw, tusks, angry yellow eyes, red helmet with horns
    Mh = Mt @ at((0, 0.28, 1.04), x=12)
    cprism(B, [(-0.18, 0.27, 0.24, 0.04), (-0.13, 0.30, 0.27, 0.05), (0.12, 0.30, 0.27, 0.05),
               (0.17, 0.25, 0.22, 0.03)], sk, M=Mh, cap_bot=False, top=sk)
    cbox(B, (0, 0.06, -0.22), (0.58, 0.44, 0.18), 0.05, skd, M=Mh, bevel=(True, False), top=skd)
    for s in (-1, 1):
        B.cone(Mh @ V((s * 0.17, 0.26, -0.16)), Mh @ V((s * 0.19, 0.30, 0.0)), 0.035, "offwhite", n=4)
        rect(B, (s * 0.12, 0.27, 0.03), 0.12, 0.09, "eyeyellow", M=Mh)
        rect(B, (s * 0.11, 0.272, 0.025), 0.04, 0.045, "black", M=Mh)
        rect(B, (s * 0.12, 0.273, 0.10), 0.17, 0.045, "black", M=Mh, rot=s * 0.45)
    rect(B, (0, 0.27, -0.07), 0.22, 0.04, "black", M=Mh)
    cbox(B, (0, -0.02, 0.21), (0.66, 0.60, 0.20), 0.06, red, M=Mh, bevel=(False, True), splits=(0.05,),
         side=lambda band, f: redd if band == 0 else None, top=red)
    for s in (-1, 1):
        B.cone(Mh @ V((s * 0.22, 0.0, 0.26)), Mh @ V((s * 0.40, -0.04, 0.50)), 0.06, met, n=4)
    # pauldrons (metal rim, red), spikes; arms with red bracers; big fists
    for s in (-1, 1):
        Mp = Mt @ at((s * 0.72, 0.0, 0.86), y=s * 22)
        cbox(B, (0, 0, 0), (0.62, 0.72, 0.42), 0.10, red, M=Mp, bevel=(True, True), splits=(0.16,),
             side=lambda band, f: met if band <= 1 else None)
        B.cone(Mp @ V((0.0, 0.0, 0.20)), Mp @ V((0.04, -0.02, 0.48)), 0.07, met, n=4)
        B.cone(Mp @ V((s * 0.26, 0.0, 0.10)), Mp @ V((s * 0.50, -0.02, 0.26)), 0.06, met, n=4)
        sh = Mt @ V((s * 0.74, 0.02, 0.62))
        el, wr = V((s * 0.98, 0.20, 1.45)), V((s * 0.86, 0.42, 0.92))
        csweep(B, [sh, el, wr], [(0.34, 0.34), (0.30, 0.30), (0.30, 0.30)], 0.05, sk, cap_top=False, cap_bot=False)
        csweep(B, [el + (wr - el) * 0.30, wr + (wr - el) * 0.05], [(0.44, 0.44), (0.44, 0.44)], 0.06, red,
               caps=(redd, redd))
        fc = wr + V((0, 0.04, -0.17))
        cbox(B, tuple(fc), (0.40, 0.38, 0.36), 0.06, skd, bevel=(True, True))
        for k in (-1, 0, 1):
            b = fc + V((k * 0.11, 0.19, 0.05))
            B.cone(b, b + V((0, 0.07, 0.0)), 0.03, met, n=4)


# ----------------------------------------------------------------------------- main
JOBS = [
    ("chr_soldier_a", lambda B: soldier(B, "a")), ("chr_soldier_b", lambda B: soldier(B, "b")),
    ("chr_soldier_c", lambda B: soldier(B, "c")),
    ("wpn_pistol", pistol), ("wpn_rifle", rifle), ("wpn_shotgun", shotgun),
    ("wpn_gatling", gatling), ("wpn_rocket", rocket),
    ("enm_walker", walker), ("enm_walker_lod1", lambda B: walker(B, lod=True)),
    ("enm_runner", runner), ("enm_runner_lod1", lambda B: runner(B, lod=True)),
    ("enm_elite_brute", elite_brute),
]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    L.reset_scene()
    mat = L.palette_material(PALETTE)
    os.makedirs(OUT, exist_ok=True)
    for name, fn in JOBS:
        if argv and name not in argv:
            continue
        B = L.Builder()
        fn(B)
        if name in WPN_SCALE:   # v2 weapon shapes: scale about the v2 grip, then move to the v3 hands
            k = WPN_SCALE[name]
            B.verts = [(RH2 + (v - RH2) * k + DELTA) * SOLDIER_S for v in B.verts]
        else:
            dz = min(v.z for v in B.verts)
            assert abs(dz) < 0.03, (name, dz)
            B.verts = [(v - V((0, 0, dz))) * SCALE.get(name, 1.0) for v in B.verts]
        ob = B.build(name, mat)
        ys = [v.co.y for v in ob.data.vertices]
        L.export_glb(ob, os.path.join(OUT, name + ".glb"))
        print("EXPORTED %-18s %4d tris  dims %s  fwd %.3f  back %.3f" % (
            name, len(ob.data.polygons), tuple(round(d, 3) for d in ob.dimensions), max(ys), -min(ys)))


main()
