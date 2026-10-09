"""v3 helpers: Kenney-style chamfered ("bevelled blocky") primitives on top of lowpoly_lib.Builder.

Cross-sections are rectangles with chamfered corners (octagons). Facet index k (between ring
points k and k+1), seen from +Z with the character facing +Y:
  0 = +X side, 1 = front-right corner, 2 = front (+Y), 3 = front-left, 4 = -X side,
  5 = back-left, 6 = back (-Y), 7 = back-right.
"""
import math
from mathutils import Matrix, Vector

V = Vector
F_R, F_FR, F_F, F_FL, F_L, F_BL, F_B, F_BR = range(8)
BACK = (F_BL, F_B, F_BR)
SIDES = (F_R, F_L)


def oct_ring(hx, hy, c, cx=0.0, cy=0.0):
    c = max(0.0, min(c, hx * 0.9, hy * 0.9))
    return [(cx + hx, cy - hy + c), (cx + hx, cy + hy - c), (cx + hx - c, cy + hy), (cx - hx + c, cy + hy),
            (cx - hx, cy + hy - c), (cx - hx, cy - hy + c), (cx - hx + c, cy - hy), (cx + hx - c, cy - hy)]


def cprism(B, rings, color, M=None, side=None, top=None, bottom=None, cap_top=True, cap_bot=True):
    """rings: (z, hx, hy, c[, cx, cy]) bottom->top in local space. side(band, facet) -> swatch or None."""
    M = M or Matrix.Identity(4)
    base = len(B.verts)
    for r in rings:
        z, hx, hy, c = r[:4]
        cx, cy = (r[4], r[5]) if len(r) > 4 else (0.0, 0.0)
        for x, y in oct_ring(hx, hy, c, cx, cy):
            B.verts.append(M @ V((x, y, z)))
    R = len(rings)
    for r in range(R - 1):
        for i in range(8):
            j = (i + 1) % 8
            col = (side(r, i) if side else None) or color
            B.faces.append(([base + r * 8 + i, base + r * 8 + j, base + (r + 1) * 8 + j, base + (r + 1) * 8 + i], col))
    if cap_bot:
        B.faces.append(([base + i for i in reversed(range(8))], bottom or color))
    if cap_top:
        B.faces.append(([base + (R - 1) * 8 + i for i in range(8)], top or color))


def cbox(B, center, size, c, color, M=None, bevel=(True, True), splits=(), side=None, top=None, bottom=None,
         cap_top=True, cap_bot=True, inset=None):
    """Chamfered box. bevel=(bottom, top) adds a chamfer ring; splits = extra ring heights measured from the
    bottom (for colour bands). Band index counts from the bottom ring."""
    cx, cy, cz = center
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    k = c if inset is None else inset
    rings = []
    if bevel[0]:
        rings.append((cz - hz, hx - k, hy - k, c * 0.5, cx, cy))
        rings.append((cz - hz + k, hx, hy, c, cx, cy))
    else:
        rings.append((cz - hz, hx, hy, c, cx, cy))
    for s in splits:
        rings.append((cz - hz + s, hx, hy, c, cx, cy))
    if bevel[1]:
        rings.append((cz + hz - k, hx, hy, c, cx, cy))
        rings.append((cz + hz, hx - k, hy - k, c * 0.5, cx, cy))
    else:
        rings.append((cz + hz, hx, hy, c, cx, cy))
    rings.sort(key=lambda r: r[0])
    cprism(B, rings, color, M, side, top, bottom, cap_top, cap_bot)


def frame(t, up=(0, 0, 1)):
    t = V(t).normalized()
    upv = V(up)
    if abs(t.dot(upv.normalized())) > 0.97:
        upv = V((0, 1, 0)) if abs(t.y) < 0.9 else V((1, 0, 0))
    x = upv.cross(t).normalized()
    y = t.cross(x).normalized()
    return x, y, t


def csweep(B, pts, sizes, c, colors, up=(0, 0, 1), caps=None, cap_top=True, cap_bot=True, M=None):
    """Chamfered tube through pts; sizes = (w, d) per point (w along the frame x axis)."""
    M = M or Matrix.Identity(4)
    pts = [V(p) for p in pts]
    m = len(pts)
    if isinstance(colors, str):
        colors = [colors] * (m - 1)
    base = len(B.verts)
    for i, p in enumerate(pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == m - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        x, y, t = frame(t, up)
        w, d = sizes[i]
        for u, v in oct_ring(w / 2, d / 2, c):
            B.verts.append(M @ (p + x * u + y * v))
    for i in range(m - 1):
        for j in range(8):
            jj = (j + 1) % 8
            B.faces.append(([base + i * 8 + j, base + i * 8 + jj, base + (i + 1) * 8 + jj, base + (i + 1) * 8 + j],
                            colors[i]))
    cb, ct = caps or (colors[0], colors[-1])
    if cap_bot:
        B.faces.append(([base + j for j in reversed(range(8))], cb))
    if cap_top:
        B.faces.append(([base + (m - 1) * 8 + j for j in range(8)], ct))


def rect(B, center, w, h, color, normal=(0, 1, 0), M=None, rot=0.0, offset=0.004):
    """Flat face feature (eye, mouth, badge): a 2-tri rectangle."""
    B.decal(center, w / 2, h / 2, color, n=4, normal=normal, M=M, rot=rot, phase=math.pi / 4, offset=offset)
    # Builder.decal with n=4 uses radius on the diagonal; compensate so w/h are true sizes
    idx, col = B.faces[-1]
    cen = sum((B.verts[i] for i in idx), V()) / 4
    for i in idx:
        B.verts[i] = cen + (B.verts[i] - cen) * math.sqrt(2)


def rotm(x=0.0, y=0.0, z=0.0):
    return (Matrix.Rotation(math.radians(z), 4, 'Z') @ Matrix.Rotation(math.radians(y), 4, 'Y') @
            Matrix.Rotation(math.radians(x), 4, 'X'))


def at(p, x=0.0, y=0.0, z=0.0):
    return Matrix.Translation(V(p)) @ rotm(x, y, z)
