"""v2 chibi character + weapon generator (art style B, palette UVs only).

Usage (repo root):
  blender -b --factory-startup -P tools/art/gen_characters.py [-- name1 name2 ...]
Outputs assets/models/*.glb. Authored directly in metres, Blender space (Z up, faces +Y);
the glTF exporter writes Y-up / facing -Z. Origin = centre between the feet.

Models: chr_soldier_a/b/c (gear tiers, shared pose), wpn_pistol/rifle/shotgun/gatling/rocket
(aligned to the soldier hands at offset 0), enm_walker(+_lod1), enm_runner(+_lod1), enm_elite_brute.
v1 generator is kept in tools/art/_v1/.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lowpoly_lib as L  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PALETTE = os.path.join(ROOT, "assets", "textures", "palette.png")
OUT = os.path.join(ROOT, "assets", "models")

V = Vector
FRONT8 = math.pi / 2 - math.pi / 8     # phase that puts a flat facet facing +Y
FRONT6 = math.pi / 2 - math.pi / 6


def rotm(x=0.0, y=0.0, z=0.0):
    return (Matrix.Rotation(math.radians(z), 4, 'Z') @ Matrix.Rotation(math.radians(y), 4, 'Y') @
            Matrix.Rotation(math.radians(x), 4, 'X'))


def at(p, x=0.0, y=0.0, z=0.0):
    return Matrix.Translation(V(p)) @ rotm(x, y, z)


# ----------------------------------------------------------------------------- soldier
# Shared pose: both hands in front of the belly, weapon axis along +Y.
RH = V((0.11, 0.20, 0.70))      # right hand (grip)
LH = V((-0.02, 0.36, 0.735))    # left hand (support)
GX, GZ = 0.055, 0.775           # weapon axis x / z

HEAD_PROFILE = [  # (z, rx, ry, cx, cy): chin, jaw, flat face band | helmet rim, dome
    (0.86, 0.17, 0.15, 0, 0.03), (1.00, 0.33, 0.30, 0, 0.01), (1.22, 0.335, 0.30, 0, 0.01),
    (1.255, 0.38, 0.35, 0, -0.01), (1.33, 0.385, 0.355, 0, -0.01),
    (1.50, 0.33, 0.305, 0, 0.0), (1.62, 0.18, 0.17, 0, 0.0)]
FACE_Y = 0.31 + 0.004            # flat front facet of the face band (+ decal offset)


def soldier_face(B, tier):
    y = FACE_Y
    for s in (-1, 1):
        B.decal((s * 0.095, y, 1.105), 0.046, 0.064, "black", n=6)                     # big eyes
        B.decal((s * 0.095 - 0.014, y + 0.002, 1.13), 0.017, 0.017, "white", n=4)       # highlight
        tilt = {"a": -0.15, "b": 0.30, "c": 0.45}[tier] * s                            # brows
        bz = {"a": 1.215, "b": 1.205, "c": 1.20}[tier]
        B.decal((s * 0.10, y, bz), 0.05, 0.013, "navy" if tier != "a" else "black", n=4, rot=tilt)
    if tier == "a":
        B.decal((0, y, 1.025), 0.03, 0.012, "black", n=6)                               # small smile
    else:
        B.decal((0, y, 1.03), 0.026, 0.008, "black", n=4)


def soldier(B, tier="a"):
    # legs: boots (toe forward) + navy trousers
    for s in (-1, 1):
        x = s * 0.11
        B.sweep([(x, 0.035, 0.0), (x, 0.02, 0.16), (x, 0.0, 0.50)],
                [(0.095, 0.125), (0.088, 0.10), (0.092, 0.092)], ["black", "navy"], n=6)
    # torso
    if tier == "a":
        B.lathe([(0.44, 0.19, 0.15), (0.52, 0.20, 0.155), (0.575, 0.20, 0.155), (0.90, 0.165, 0.13)],
                ["navy", "gear", "blue"], n=8, caps=("navy", "blue"))
    elif tier == "b":
        B.lathe([(0.44, 0.19, 0.15), (0.52, 0.20, 0.155), (0.575, 0.215, 0.17), (0.86, 0.215, 0.17),
                 (0.92, 0.15, 0.12)],
                ["navy", "gear", "navy", "blue"], n=8, caps=("navy", "blue"))   # tactical vest
        B.box((0, -0.20, 0.72), (0.26, 0.12, 0.24), "gear", taper=(0.9, 0.9), top="metal")  # pack
    else:
        B.lathe([(0.44, 0.19, 0.15), (0.52, 0.205, 0.16), (0.575, 0.245, 0.195),
                 (0.83, 0.255, 0.205), (0.875, 0.225, 0.175), (0.93, 0.15, 0.12)],
                ["navy", "gold", "lightblue", "gold", "navy"], n=8, caps=("navy", "navy"))
        B.box((0, -0.24, 0.75), (0.34, 0.15, 0.30), "navy", taper=(0.9, 0.9), top="gold")   # power pack
    # head + headgear (one lathe; bands coloured per tier)
    cols = {"a": ["skin", "skin", "navy", "navy", "blue", "lightblue"],
            "b": ["skin", "skin", "navy", "gear", "blue", "lightblue"],
            "c": ["skin", "skin", "navy", "gold", "blue", "lightblue"]}[tier]
    # facets 4..7 (angles 247..337 deg, i.e. the back) of the skin bands get hair
    B.prism([(p[0], p[1], p[2], p[3], p[4]) for p in HEAD_PROFILE], "skin", 8, None,
            top="lightblue", bottom="skin", phase=FRONT8,
            side=lambda r, i: ("ragbrown" if (r == 1 and i in (2, 3, 4, 5, 6)) or (r == 0 and i in (3, 4, 5))
                               else cols[r]))
    soldier_face(B, tier)
    if tier == "a":   # cap bill
        B.box((0, 0.37, 1.305), (0.36, 0.14, 0.03), "navy", taper=(0.85, 0.7), rot=(-8, 0, 0))
    elif tier == "b":  # goggles on the helmet rim
        B.decal((0, 0.358, 1.292), 0.15, 0.022, "navy", n=4)
        for s in (-1, 1):
            B.decal((s * 0.07, 0.361, 1.292), 0.042, 0.032, "lightblue", n=6)
    else:              # raised visor (decals on the dome front) + gold crest
        B.decal((0, 0.335, 1.40), 0.14, 0.045, "navy", n=4, normal=(0, 0.95, 0.31))
        B.decal((0, 0.338, 1.405), 0.12, 0.03, "lightblue", n=4, normal=(0, 0.95, 0.31))
        B.box((0, -0.02, 1.64), (0.07, 0.38, 0.09), "gold", taper=(0.6, 0.75))
    # arms (shared pose) + hands
    sleeve = ["blue", "blue"] if tier != "c" else ["blue", "navy"]
    hand = "skin" if tier != "c" else "navy"
    na = 6 if tier != "c" else 5
    B.sweep([(0.23, 0.0, 0.84), (0.27, 0.06, 0.66), (0.13, 0.17, 0.69)], [0.085, 0.075, 0.065], sleeve, n=na)
    B.sweep([(-0.23, 0.0, 0.84), (-0.24, 0.17, 0.70), (-0.04, 0.33, 0.73)], [0.085, 0.075, 0.065], sleeve, n=na)
    B.blob(tuple(RH), (0.075, 0.075, 0.07), hand, n=na, lats=(-40, 40))
    B.blob(tuple(LH), (0.075, 0.075, 0.07), hand, n=na, lats=(-40, 40))
    # shoulder armour
    for s in (-1, 1):
        if tier == "b":
            M = at((s * 0.27, 0.0, 0.86), y=s * 40)
            B.lathe([(-0.03, 0.12, 0.11), (0.06, 0.08, 0.075)], ["lightblue"], n=6, M=M)
        elif tier == "c":
            M = at((s * 0.30, -0.01, 0.87), y=s * 40)
            B.lathe([(-0.05, 0.17, 0.155), (0.09, 0.11, 0.10)], ["lightblue"], n=6, M=M, caps=("gold", "gold"))


# ----------------------------------------------------------------------------- weapons
def pistol(B):
    x, z = GX, GZ
    B.box((x, 0.27, z + 0.01), (0.06, 0.25, 0.07), "black", top="gear")              # slide
    B.box((x, 0.25, z - 0.035), (0.055, 0.21, 0.04), "gear")                         # frame
    B.box((x, 0.195, z - 0.09), (0.05, 0.065, 0.13), "black", rot=(18, 0, 0))        # grip
    B.box((x, 0.27, z - 0.07), (0.03, 0.06, 0.02), "black")                          # trigger guard
    B.sweep([(x, 0.39, z + 0.012), (x, 0.43, z + 0.012)], [0.02, 0.02], "metal", n=6)  # muzzle


def rifle(B):
    x, z = GX, GZ
    B.box((x, 0.0, z - 0.015), (0.06, 0.20, 0.10), "black", taper=(1, 0.85))         # stock
    B.box((x, 0.20, z), (0.075, 0.26, 0.10), "gear", top="metal")                    # receiver
    B.box((x, 0.25, z - 0.11), (0.05, 0.07, 0.15), "black", rot=(-12, 0, 0))         # magazine
    B.box((x, 0.165, z - 0.08), (0.045, 0.05, 0.09), "black", rot=(20, 0, 0))        # grip
    B.box((x, 0.42, z + 0.005), (0.08, 0.18, 0.085), "navy")                         # handguard
    B.box((x, 0.21, z + 0.07), (0.03, 0.10, 0.035), "black")                         # sight
    B.sweep([(x, 0.51, z + 0.01), (x, 0.73, z + 0.01)], [0.02, 0.02], "metal", n=6)   # barrel
    B.sweep([(x, 0.72, z + 0.01), (x, 0.77, z + 0.01)], [0.03, 0.03], "black", n=6)   # muzzle brake


def shotgun(B):
    x, z = GX, GZ
    B.box((x, 0.0, z - 0.02), (0.065, 0.22, 0.11), "navy", taper=(1, 0.85))          # stock
    B.box((x, 0.20, z), (0.08, 0.24, 0.11), "black", top="gear")                     # receiver
    B.box((x + 0.042, 0.20, z), (0.008, 0.15, 0.06), "gold")                         # gold plate
    B.box((x, 0.165, z - 0.085), (0.05, 0.055, 0.10), "black", rot=(20, 0, 0))       # grip
    B.sweep([(x, 0.32, z + 0.025), (x, 0.80, z + 0.025)], [0.032, 0.032], "metal", n=5)  # barrel
    B.sweep([(x, 0.32, z - 0.03), (x, 0.74, z - 0.03)], [0.026, 0.026], "black", n=5)    # mag tube
    B.sweep([(x, 0.44, z - 0.03), (x, 0.62, z - 0.03)], [0.045, 0.045], "navy", n=6)     # pump
    B.sweep([(x, 0.79, z + 0.025), (x, 0.83, z + 0.025)], [0.04, 0.04], "gold", n=5)     # gold muzzle


def gatling(B):
    x, z = GX, GZ + 0.01
    B.sweep([(x, 0.06, z), (x, 0.12, z), (x, 0.36, z)], [0.075, 0.095, 0.09],
            ["gold", "navy"], n=8, caps=("black", "metal"))                          # motor housing
    for k in range(3):
        a = math.pi / 2 + k * 2 * math.pi / 3
        ox, oz = 0.042 * math.cos(a), 0.042 * math.sin(a)
        B.sweep([(x + ox, 0.36, z + oz), (x + ox, 0.84, z + oz)], [0.022, 0.022], "metal", n=4)
    B.sweep([(x, 0.74, z), (x, 0.775, z)], [0.075, 0.075], "gold", n=5)               # barrel clamp
    B.box((x, 0.18, z - 0.10), (0.05, 0.06, 0.10), "black", rot=(15, 0, 0))          # grip
    B.box((x - 0.10, 0.22, z - 0.04), (0.10, 0.14, 0.12), "navy", top="gold")        # ammo box


def rocket(B):
    x, z = GX, GZ + 0.07
    B.sweep([(x, -0.32, z), (x, -0.26, z), (x, 0.50, z), (x, 0.56, z)], [0.085, 0.07, 0.07, 0.085],
            ["gold", "blue", "gold"], n=8, caps=("black", "black"))                  # launcher tube
    B.cone((x, 0.56, z), (x, 0.74, z), 0.06, "orangered", n=8)                       # warhead
    B.box((x, 0.19, z - 0.10), (0.05, 0.06, 0.10), "black", rot=(15, 0, 0))          # rear grip
    B.box((x - 0.01, 0.36, z - 0.09), (0.05, 0.06, 0.09), "black", rot=(15, 0, 0))   # front grip
    B.box((x + 0.09, 0.06, z + 0.05), (0.05, 0.12, 0.07), "gear", top="metal")       # sight box


# ----------------------------------------------------------------------------- zombies
def zombie_head(B, M, prof, skin, skin_dk, face, lod=False):
    """Lathe head with flat front facet; face() draws decals in head-local coords."""
    n = 6 if lod else 8
    phase = FRONT6 if lod else FRONT8
    cols = [skin_dk] + [skin] * (len(prof) - 3) + [skin_dk if len(prof) >= 6 else skin]
    B.lathe(prof, cols, n=n, M=M, caps=(skin_dk, skin_dk), phase=phase)
    face(B, M)


def walker(B, lod=False):
    n_l = 4 if lod else 6
    n_t = 6 if lod else 8
    # legs: ragged brown trousers -> green shins, chunky feet
    for s in (-1, 1):
        x = s * 0.14
        B.sweep([(x, -0.07, 0.56), (s * 0.165, 0.05, 0.31), (s * 0.17, -0.02, 0.09)],
                [0.10, 0.088, 0.075], ["ragbrown", "green"], n=n_l)
        B.blob((s * 0.17, 0.04, 0.06), (0.09, 0.13, 0.065), "dkgreen" if s < 0 else "ragbrown",
               n=n_l, lats=(-45, 45))
    # hunched torso along a curved spine
    if not lod:
        B.sweep([(0, -0.07, 0.50), (0, -0.07, 0.62), (0, 0.0, 0.90), (0, 0.12, 1.12)],
                [(0.21, 0.17), (0.22, 0.18), (0.26, 0.20), (0.29, 0.21)], ["ragbrown", "cream", "cream"],
                n=n_t, caps=("ragbrown", "green"))
    else:
        B.sweep([(0, -0.07, 0.50), (0, -0.07, 0.62), (0, 0.12, 1.12)],
                [(0.21, 0.17), (0.22, 0.18), (0.29, 0.21)], ["ragbrown", "cream"],
                n=n_t, caps=("ragbrown", "green"))
    if not lod:
        for k, a in enumerate((-140, -40, 30, 100, 150)):          # torn shirt hem tatters
            r = math.radians(a)
            bx, by = 0.225 * math.cos(r), -0.07 + 0.18 * math.sin(r)
            B.cone((bx, by, 0.64), (bx * 1.08, by * 1.08, 0.52 - 0.03 * (k % 2)), 0.05, "cream", n=3)
        B.decal((0.05, 0.155, 0.80), 0.07, 0.06, "ltgreen", n=6, normal=(0, 0.95, -0.3))  # belly hole
        B.decal((-0.12, -0.09, 1.06), 0.06, 0.05, "rotpurple", n=6, normal=(-0.3, -0.6, 0.75))
    # arms: wide, elbows out, hands forward
    for s in (-1, 1):
        sh, el, wr = V((s * 0.32, 0.10, 1.08)), V((s * 0.44, 0.18, 0.88)), V((s * 0.31, 0.33, 1.0))
        if s > 0:
            wr = wr + V((0, 0, 0.07))
        if lod:   # LOD: hand folded into a fat forearm end
            wr = wr + V((0, 0.06, 0.02))
        B.sweep([sh, el, wr], [0.088, 0.075, 0.065 if not lod else 0.085], ["cream", "green"], n=n_l)
        hc = wr + V((0, 0.05, 0.02))
        if not lod:
            B.blob(tuple(hc), (0.085, 0.075, 0.07), "green", n=n_l, lats=(-45, 45))
            for f in (-1, 1):
                b = hc + V((f * 0.045, 0.05, -0.01))
                B.cone(b, b + V((f * 0.01, 0.065, -0.035)), 0.02, "dkgreen", n=3)
    # head: big, tilted forward, droopy eyes, open mouth
    prof = [(-0.33, 0.17, 0.16, 0, 0.03), (-0.22, 0.33, 0.30), (0.10, 0.35, 0.30),
            (0.22, 0.33, 0.29), (0.33, 0.22, 0.20), (0.37, 0.10, 0.10)]
    if lod:
        prof = [prof[0], prof[1], prof[2], (0.30, 0.27, 0.24), prof[5]][:4] + [(0.37, 0.12, 0.12)]
        prof = [prof[0], prof[1], prof[2], prof[4]]
        prof[-1] = (0.36, 0.20, 0.18)
    M = at((0.02, 0.20, 1.40), x=-8, y=5, z=-4)
    fy = 0.305 if not lod else 0.305

    def face(B, M):
        nn = 4 if lod else 6
        B.decal((-0.115, fy, 0.0), 0.064, 0.06, "offwhite", n=nn, M=M)
        B.decal((0.10, fy, 0.01), 0.074, 0.068, "offwhite", n=nn, M=M)
        B.decal((-0.10, fy + 0.002, -0.02), 0.022, 0.022, "black", n=4, M=M)          # pupils (low)
        B.decal((0.085, fy + 0.002, -0.015), 0.026, 0.026, "black", n=4, M=M)
        B.decal((-0.115, fy + 0.004, 0.035), 0.07, 0.026, "dkgreen", n=4, M=M, rot=0.15)   # droopy lids
        B.decal((0.10, fy + 0.004, 0.05), 0.08, 0.027, "dkgreen", n=4, M=M, rot=-0.2)
        B.decal((0.0, fy, -0.155), 0.085, 0.05, "black", n=nn, M=M)                    # open mouth
        if not lod:
            B.decal((0.03, fy + 0.002, -0.12), 0.018, 0.016, "offwhite", n=4, M=M)      # tooth
            B.decal((-0.02, fy + 0.002, -0.18), 0.03, 0.02, "elitered", n=4, M=M)       # tongue
    zombie_head(B, M, prof, "green", "dkgreen", face, lod)
    if not lod:   # hair tufts + stitched rot patch
        for tx, ty in ((-0.06, -0.02), (0.05, 0.03), (0.0, -0.10)):
            b = M @ V((tx, ty, 0.33))
            B.cone(b, M @ V((tx * 1.6, ty - 0.06, 0.45)), 0.035, "dkgreen", n=3)


def runner(B, lod=False):
    n_l = 4 if lod else 6
    n_t = 6 if lod else 8
    skin, skd = "ltgreen", "green"
    # long stride: front (left) leg forward, back (right) leg kicked up
    B.sweep([(-0.10, -0.02, 0.63), (-0.12, 0.25, 0.43), (-0.12, 0.19, 0.09)],
            [0.08, 0.07, 0.06], ["ragbrown", skin], n=n_l)
    B.blob((-0.12, 0.25, 0.05), (0.07, 0.11, 0.05), "rotpurple", n=n_l, lats=(-60, 0, 60) if not lod else (-50, 50))
    B.sweep([(0.10, -0.06, 0.63), (0.11, -0.17, 0.37), (0.11, -0.40, 0.38)],
            [0.08, 0.07, 0.06], ["ragbrown", skin], n=n_l)
    B.blob((0.11, -0.46, 0.34), (0.065, 0.06, 0.10), skd, n=n_l, lats=(-60, 0, 60) if not lod else (-50, 50))
    # lean torso, narrow shoulders, purple torn tank top
    if not lod:
        B.sweep([(0, -0.05, 0.56), (0, -0.03, 0.68), (0, 0.13, 0.92), (0, 0.23, 1.05)],
                [(0.15, 0.12), (0.15, 0.12), (0.16, 0.12), (0.17, 0.12)], ["ragbrown", "rotpurple", "rotpurple"],
                n=n_t, caps=("ragbrown", skin))
    else:
        B.sweep([(0, -0.05, 0.56), (0, -0.03, 0.68), (0, 0.23, 1.05)],
                [(0.15, 0.12), (0.15, 0.12), (0.17, 0.12)], ["ragbrown", "rotpurple"],
                n=n_t, caps=("ragbrown", skin))
    if not lod:
        for k, a in enumerate((-140, -60, 30, 110)):
            r = math.radians(a)
            bx, by = 0.15 * math.cos(r), -0.03 + 0.12 * math.sin(r)
            B.cone((bx, by, 0.72), (bx * 1.1, by * 1.1 - 0.03, 0.62), 0.04, "rotpurple", n=3)
        B.decal((0.0, -0.04, 0.85), 0.05, 0.05, skin, n=6, normal=(0, -0.8, 0.6))      # rip on the back
        B.cone((0.05, -0.08, 0.62), (0.08, -0.30, 0.66), 0.04, "ragbrown", n=3)          # flapping rag
    # arms pumping: right forward, left back
    B.sweep([(0.19, 0.21, 1.00), (0.24, 0.34, 0.85), (0.19, 0.43, 0.98)], [0.06, 0.052, 0.048], [skin, skin], n=n_l)
    if not lod:
        B.blob((0.185, 0.46, 1.01), (0.055, 0.055, 0.055), skd, n=n_l, lats=(-45, 45))
    B.sweep([(-0.19, 0.17, 1.00), (-0.24, -0.02, 0.88), (-0.22, -0.17, 1.02)], [0.06, 0.052, 0.048], [skin, skin], n=n_l)
    if not lod:
        B.blob((-0.22, -0.21, 1.05), (0.055, 0.055, 0.055), skd, n=n_l, lats=(-45, 45))
    # head: crazy wide eyes, tongue out, hair spikes swept back
    prof = [(-0.29, 0.15, 0.14, 0, 0.03), (-0.20, 0.29, 0.26), (0.08, 0.30, 0.26),
            (0.19, 0.28, 0.25), (0.28, 0.18, 0.17), (0.31, 0.08, 0.08)]
    if lod:
        prof = [prof[0], prof[1], prof[2], (0.30, 0.17, 0.16)]
    M = at((0.0, 0.29, 1.36), x=6, z=3)
    fy = 0.265

    def face(B, M):
        nn = 4 if lod else 6
        B.decal((-0.10, fy, 0.0), 0.075, 0.075, "offwhite", n=nn, M=M)
        B.decal((0.095, fy, 0.005), 0.058, 0.058, "offwhite", n=nn, M=M)
        B.decal((-0.09, fy + 0.002, 0.0), 0.02, 0.02, "black", n=4, M=M)
        B.decal((0.085, fy + 0.002, 0.0), 0.017, 0.017, "black", n=4, M=M)
        B.decal((-0.10, fy + 0.002, 0.10), 0.06, 0.012, "dkgreen", n=4, M=M, rot=-0.3)    # brows up
        B.decal((0.10, fy + 0.002, 0.09), 0.05, 0.012, "dkgreen", n=4, M=M, rot=0.35)
        B.decal((0.0, fy, -0.14), 0.09, 0.045, "black", n=nn, M=M)                        # grin
        B.decal((0.03, fy + 0.002, -0.17), 0.03, 0.035, "orangered", n=4, M=M)            # tongue out
    zombie_head(B, M, prof, skin, skd, face, lod)
    spikes = ((0.0, -0.02), (-0.09, -0.04), (0.09, -0.05)) if not lod else ((0.0, -0.03),)
    for tx, ty in spikes:
        b = M @ V((tx, ty, 0.27))
        B.cone(b, M @ V((tx * 1.3, ty - 0.20, 0.38)), 0.05, "dkgreen", n=3)


def elite_brute(B):
    sk, skd, red, redd, met = "green", "dkgreen", "elitered", "bossred", "metal"
    # stumpy legs + big feet + red knee plates
    for s in (-1, 1):
        x = s * 0.36
        B.sweep([(x, -0.06, 1.05), (s * 0.40, 0.04, 0.55), (s * 0.40, 0.0, 0.16)],
                [0.20, 0.17, 0.15], ["ragbrown", skd], n=8)
        B.blob((s * 0.40, 0.08, 0.10), (0.19, 0.27, 0.12), skd, n=8, lats=(-70, -10, 50))
        for t in (-0.1, 0.0, 0.1):
            b = V((s * 0.40 + t, 0.32, 0.07))
            B.cone(b, b + V((t * 0.3, 0.09, -0.03)), 0.035, "offwhite", n=3)
        B.blob((s * 0.41, 0.17, 0.58), (0.15, 0.08, 0.15), red, n=6, lats=(-45, 0, 45), colors=[redd, red])
        B.box((s * 0.42, 0.0, 0.88), (0.10, 0.30, 0.22), met, rot=(0, s * 20, 0), top=met)  # thigh scrap
    # pelvis + belt + loincloth
    B.lathe([(0.98, 0.42, 0.30), (1.10, 0.48, 0.34), (1.22, 0.50, 0.36), (1.30, 0.50, 0.36)],
            ["ragbrown", "ragbrown", met], n=8, caps=("ragbrown", met))
    B.box((0, 0.33, 0.95), (0.40, 0.06, 0.36), "ragbrown", taper=(0.8, 1), rot=(10, 0, 0))
    B.box((0, 0.37, 1.24), (0.14, 0.04, 0.10), "gold")                                    # belt plate
    # massive hunched torso
    B.sweep([(0, -0.08, 1.20), (0, -0.04, 1.45), (0, 0.06, 1.85), (0, 0.18, 2.12), (0, 0.24, 2.24)],
            [(0.46, 0.33), (0.52, 0.38), (0.66, 0.46), (0.62, 0.42), (0.40, 0.28)],
            ["ltgreen", sk, sk, sk], n=10, caps=(sk, skd))
    # red chest armour (curved plate) + rivets
    B.lathe([(-0.28, 0.44, 0.10), (0.0, 0.52, 0.13), (0.22, 0.50, 0.12), (0.32, 0.40, 0.09)],
            [redd, red, red], n=8, M=at((0, 0.42, 1.68), x=-18), caps=(redd, redd))
    for s in (-1, 1):
        B.cone(V((s * 0.26, 0.60, 1.76)), V((s * 0.27, 0.67, 1.78)), 0.03, met, n=4)
    # back plates + spikes + rot wound
    B.lathe([(-0.30, 0.44, 0.08), (0.28, 0.48, 0.09)], [met], n=6, M=at((0, -0.33, 1.86), x=20))
    for x, h in ((-0.22, 0.30), (0.0, 0.40), (0.22, 0.30)):
        b = V((x, -0.38, 2.05))
        B.cone(b, b + V((x * 0.4, -0.18, h)), 0.07, met, n=4)
    B.decal((0.30, -0.36, 1.55), 0.09, 0.07, "rotpurple", n=6, normal=(0.4, -0.9, 0.1))
    # head: sunk between the shoulders, underbite with tusks, angry glowing eyes, helmet plate
    hm = at((0, 0.36, 2.30), x=-6)
    prof = [(-0.25, 0.22, 0.20, 0, 0.05), (-0.14, 0.33, 0.29, 0, 0.03), (0.10, 0.33, 0.27),
            (0.20, 0.30, 0.25), (0.27, 0.18, 0.16)]
    B.lathe(prof, [skd, sk, sk, sk], n=8, M=hm, caps=(skd, skd), phase=FRONT8)
    B.blob((0, 0.10, -0.19), (0.30, 0.22, 0.12), skd, n=8, lats=(-40, 10, 50), M=hm)        # jaw
    for s in (-1, 1):
        b = hm @ V((s * 0.17, 0.27, -0.14))
        B.cone(b, hm @ V((s * 0.20, 0.30, 0.0)), 0.035, "offwhite", n=4)                   # tusks
        B.decal((s * 0.11, 0.276, 0.04), 0.06, 0.045, "eyeyellow", n=6, M=hm)
        B.decal((s * 0.10, 0.278, 0.035), 0.02, 0.022, "black", n=4, M=hm)
        B.decal((s * 0.11, 0.279, 0.10), 0.085, 0.022, "black", n=4, M=hm, rot=s * 0.45)  # angry brows
    B.decal((0, 0.275, -0.06), 0.11, 0.025, "black", n=4, M=hm)                            # mouth line
    B.lathe([(0.12, 0.36, 0.30), (0.20, 0.35, 0.29), (0.30, 0.22, 0.19)], [red, redd], n=8, M=hm,
            caps=(redd, redd))                                                              # helmet
    for s in (-1, 1):
        B.cone(hm @ V((s * 0.18, 0.0, 0.26)), hm @ V((s * 0.34, -0.04, 0.48)), 0.05, met, n=4)  # horns
    # shoulders: huge red pauldrons with metal rims + spikes
    for s in (-1, 1):
        sh = V((s * 0.78, 0.10, 2.10))
        M = at(sh, y=s * 25)
        B.lathe([(-0.24, 0.36, 0.34), (-0.16, 0.40, 0.38), (0.05, 0.40, 0.38), (0.18, 0.30, 0.29),
                 (0.25, 0.14, 0.14)], [met, red, red, red], n=8, M=M, caps=(redd, redd))
        B.cone(M @ V((0.05, 0.0, 0.20)), M @ V((0.12, -0.02, 0.50)), 0.07, met, n=4)
        B.cone(M @ V((s * 0.22, 0.0, 0.12)), M @ V((s * 0.45, -0.02, 0.30)), 0.06, met, n=4)
        # gorilla arms: fists low in front
        elb, wr = V((s * 0.98, 0.26, 1.48)), V((s * 0.86, 0.52, 0.90))
        B.sweep([sh + V((0, 0, -0.08)), elb, wr], [0.19, 0.17, 0.20], [sk, sk], n=8)
        B.sweep([elb + (wr - elb) * 0.35, elb + (wr - elb) * 0.70, wr + (wr - elb) * 0.05],
                [0.235, 0.25, 0.24], [red, redd], n=8, caps=(redd, redd))                   # bracer
        fc = wr + V((0, 0.03, -0.17))
        B.blob(tuple(fc), (0.21, 0.21, 0.18), skd, n=8, lats=(-55, 0, 55))                 # fist
        for k in (-1, 0, 1):
            b = fc + V((k * 0.10, 0.18, 0.04))
            B.cone(b, b + V((0, 0.08, 0.02)), 0.03, met, n=4)                               # knuckle studs


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


SOLDIER_DZ = [None]
WPN_SCALE = {"wpn_pistol": 1.45, "wpn_rifle": 1.3, "wpn_shotgun": 1.3, "wpn_gatling": 1.35, "wpn_rocket": 1.25}


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
        if name in WPN_SCALE:   # chibi-exaggerated weapons, scaled about the right-hand grip
            k = WPN_SCALE[name]
            B.verts = [RH + (v - RH) * k for v in B.verts]
        if not name.startswith("wpn_"):   # feet exactly on Y=0 (tilted end rings can dip ~1 cm)
            dz = min(v.z for v in B.verts)
            B.verts = [v - V((0, 0, dz)) for v in B.verts]
            if name.startswith("chr_soldier"):
                SOLDIER_DZ[0] = dz
        elif SOLDIER_DZ[0] is not None:     # keep weapons aligned with the shifted soldier hands
            B.verts = [v - V((0, 0, SOLDIER_DZ[0])) for v in B.verts]
        ob = B.build(name, mat)
        ys = [v.co.y for v in ob.data.vertices]
        L.export_glb(ob, os.path.join(OUT, name + ".glb"))
        print("EXPORTED %-18s %4d tris  dims %s  fwd %.3f  back %.3f" % (
            name, len(ob.data.polygons), tuple(round(d, 3) for d in ob.dimensions), max(ys), -min(ys)))


main()
