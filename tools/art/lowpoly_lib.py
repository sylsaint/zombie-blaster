"""Shared helpers for palette-UV low-poly character generation (Blender 4.x, bpy).

Coordinates are authored in Blender space: Z up, character faces +Y, origin at feet.
The glTF exporter converts to Y-up / facing -Z.
"""
import math
import bpy
import bmesh
from mathutils import Vector, Matrix

PALETTE_COLS, PALETTE_ROWS = 8, 4

# (row, col) swatches, names match docs/art/style-guide.md section 3
SW = {
    # row 0 friendly
    "navy": (0, 0), "blue": (0, 1), "lightblue": (0, 2), "skin": (0, 3),
    "gear": (0, 4), "metal": (0, 5), "gold": (0, 6), "offwhite": (0, 7),
    # row 1 enemy
    "dkgreen": (1, 0), "green": (1, 1), "ltgreen": (1, 2), "rotpurple": (1, 3),
    "ragbrown": (1, 4), "elitered": (1, 5), "bossred": (1, 6), "eyeyellow": (1, 7),
    # row 2 environment
    "dkteal": (2, 0), "teal": (2, 1), "water": (2, 2), "cream": (2, 3),
    "sand": (2, 4), "rock": (2, 5), "asphalt": (2, 6), "grass": (2, 7),
    # row 3 fx / ui
    "orange": (3, 0), "orangered": (3, 1), "fireyellow": (3, 2), "buffcyan": (3, 3),
    "debuffpink": (3, 4), "healgreen": (3, 5), "black": (3, 6), "white": (3, 7),
}


def swatch_uv(name):
    r, c = SW[name]
    # Blender UV origin is bottom-left; image row 0 is the top of the PNG.
    return ((c + 0.5) / PALETTE_COLS, 1.0 - (r + 0.5) / PALETTE_ROWS)


class Builder:
    """Accumulates closed prisms into one mesh; each face carries a swatch name."""

    def __init__(self):
        self.verts = []
        self.faces = []  # (indices, swatch)

    # rings: list of (z, rx, ry, cx, cy) in local space; n sides.
    def prism(self, rings, color, n=4, M=None, top=None, bottom=None, side=None, phase=None):
        M = M or Matrix.Identity(4)
        if phase is None:
            phase = math.pi / n
        k = 1.0 / math.cos(math.pi / n)  # rx/ry are apothems (half-widths for a box)
        base = len(self.verts)
        for (z, rx, ry, cx, cy) in rings:
            for i in range(n):
                a = phase + 2 * math.pi * i / n
                v = Vector((cx + rx * k * math.cos(a), cy + ry * k * math.sin(a), z))
                self.verts.append(M @ v)
        R = len(rings)
        for r in range(R - 1):
            for i in range(n):
                j = (i + 1) % n
                f = [base + r * n + i, base + r * n + j, base + (r + 1) * n + j, base + (r + 1) * n + i]
                col = color
                if side:
                    col = side(r, i) or color
                self.faces.append((f, col))
        self.faces.append(([base + i for i in reversed(range(n))], bottom or color))
        self.faces.append(([base + (R - 1) * n + i for i in range(n)], top or color))

    def cone(self, base, tip, r, color, n=4, up=(0, 0, 1), tipcolor=None):
        """n-sided pyramid/spike from base centre to tip (n + n-2 tris)."""
        base, tip = Vector(base), Vector(tip)
        zax = (tip - base).normalized()
        upv = Vector(up)
        if abs(zax.dot(upv)) > 0.95:
            upv = Vector((0, 1, 0))
        xax = upv.cross(zax).normalized()
        yax = zax.cross(xax).normalized()
        b0 = len(self.verts)
        k = 1.0 / math.cos(math.pi / n)
        for i in range(n):
            a = math.pi / n + 2 * math.pi * i / n
            self.verts.append(base + xax * (r * k * math.cos(a)) + yax * (r * k * math.sin(a)))
        self.verts.append(tip)
        for i in range(n):
            self.faces.append(([b0 + i, b0 + (i + 1) % n, b0 + n], tipcolor or color))
        self.faces.append(([b0 + i for i in reversed(range(n))], color))

    def box(self, center, size, color, taper=(1.0, 1.0), shift=(0.0, 0.0), rot=None, **kw):
        """Axis box (optionally rotated about its centre). taper scales the top ring."""
        sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
        rings = [(-sz, sx, sy, 0, 0), (sz, sx * taper[0], sy * taper[1], shift[0], shift[1])]
        M = Matrix.Translation(Vector(center))
        if rot:
            M = M @ (Matrix.Rotation(math.radians(rot[2]), 4, 'Z') @
                     Matrix.Rotation(math.radians(rot[1]), 4, 'Y') @
                     Matrix.Rotation(math.radians(rot[0]), 4, 'X'))
        self.prism(rings, color, 4, M, **kw)

    def limb(self, p0, p1, w0, d0, w1=None, d1=None, color="blue", up=(0, 0, 1), n=4, ext=0.0, **kw):
        """Tapered box/prism from p0 to p1 (local Z along the segment)."""
        p0, p1 = Vector(p0), Vector(p1)
        d = (p1 - p0)
        L = d.length
        zax = d.normalized()
        upv = Vector(up)
        if abs(zax.dot(upv)) > 0.95:
            upv = Vector((0, 1, 0))
        xax = upv.cross(zax).normalized()
        yax = zax.cross(xax).normalized()
        M = Matrix((
            (xax.x, yax.x, zax.x, p0.x),
            (xax.y, yax.y, zax.y, p0.y),
            (xax.z, yax.z, zax.z, p0.z),
            (0, 0, 0, 1)))
        w1 = w0 if w1 is None else w1
        d1 = d0 if d1 is None else d1
        rings = [(-ext, w0 / 2, d0 / 2, 0, 0), (L + ext, w1 / 2, d1 / 2, 0, 0)]
        self.prism(rings, color, n, M, **kw)

    # ---------- v2 primitives ----------
    @staticmethod
    def _frame(t, up):
        t = Vector(t).normalized()
        upv = Vector(up)
        if abs(t.dot(upv.normalized())) > 0.97:
            upv = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
        x = upv.cross(t).normalized()
        y = t.cross(x).normalized()
        return x, y, t

    def sweep(self, pts, radii, colors, n=6, up=(0, 0, 1), M=None, caps=None, phase=None):
        """Generalised tube through pts. radii: (rx, ry) per point (or float).
        colors: one swatch per band (len(pts)-1) or a single name. caps: (bottom, top)."""
        M = M or Matrix.Identity(4)
        if phase is None:
            phase = math.pi / n
        pts = [Vector(p) for p in pts]
        m = len(pts)
        if isinstance(colors, str):
            colors = [colors] * (m - 1)
        k = 1.0 / math.cos(math.pi / n)
        base = len(self.verts)
        for i, p in enumerate(pts):
            if i == 0:
                t = pts[1] - pts[0]
            elif i == m - 1:
                t = pts[-1] - pts[-2]
            else:
                t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
            x, y, t = self._frame(t, up)
            r = radii[i]
            rx, ry = (r, r) if isinstance(r, (int, float)) else r
            for j in range(n):
                a = phase + 2 * math.pi * j / n
                self.verts.append(M @ (p + x * (rx * k * math.cos(a)) + y * (ry * k * math.sin(a))))
        for i in range(m - 1):
            for j in range(n):
                jj = (j + 1) % n
                self.faces.append(([base + i * n + j, base + i * n + jj, base + (i + 1) * n + jj,
                                    base + (i + 1) * n + j], colors[i]))
        cb, ct = caps or (colors[0], colors[-1])
        self.faces.append(([base + j for j in reversed(range(n))], cb))
        self.faces.append(([base + (m - 1) * n + j for j in range(n)], ct))

    def lathe(self, profile, colors, n=8, M=None, caps=None, phase=None):
        """profile: list of (z, rx, ry[, cx, cy]) rings bottom->top; colors per band."""
        rings = [(p[0], p[1], p[2], p[3] if len(p) > 3 else 0.0, p[4] if len(p) > 4 else 0.0)
                 for p in profile]
        if isinstance(colors, str):
            colors = [colors] * (len(rings) - 1)
        cb, ct = caps or (colors[0], colors[-1])
        self.prism(rings, colors[0], n, M, top=ct, bottom=cb, side=lambda r, i: colors[r], phase=phase)

    def blob(self, center, radii, color, n=6, lats=(-50, 10, 55), M=None, colors=None, phase=None):
        """Low-poly ellipsoid made of latitude rings with flat caps."""
        cx, cy, cz = center
        rx, ry, rz = radii
        prof = [(cz + rz * math.sin(math.radians(a)), rx * math.cos(math.radians(a)),
                 ry * math.cos(math.radians(a)), cx, cy) for a in lats]
        cols = colors or [color] * (len(prof) - 1)
        self.lathe(prof, cols, n, M, phase=phase)

    def decal(self, center, rx, rz, color, n=6, normal=(0, 1, 0), M=None, rot=0.0, phase=None, offset=0.0):
        """Single-sided flat polygon (face features). Lies in the plane facing `normal`."""
        M = M or Matrix.Identity(4)
        N = Vector(normal).normalized()
        upv = Vector((0, 0, 1)) if abs(N.z) < 0.9 else Vector((0, 1, 0))
        x = N.cross(upv).normalized()   # character's +X when N faces +Y
        z = x.cross(N).normalized()     # up
        if phase is None:
            phase = math.pi / 2 if n % 2 == 0 and n != 4 else (math.pi / 4 if n == 4 else math.pi / 2)
        c = Vector(center) + N * offset
        ca, sa = math.cos(rot), math.sin(rot)
        base = len(self.verts)
        for j in range(n):
            a = phase + 2 * math.pi * j / n
            u, v = rx * math.cos(a), rz * math.sin(a)
            u, v = u * ca - v * sa, u * sa + v * ca
            self.verts.append(M @ (c + x * u + z * v))
        idx = [base + j for j in range(n)]
        # winding so the normal points along N
        v0, v1, v2 = (self.verts[idx[0]], self.verts[idx[1]], self.verts[idx[2]])
        nrm = (v1 - v0).cross(v2 - v0)
        if nrm.dot((M.to_3x3() @ N)) < 0:
            idx.reverse()
        self.faces.append((idx, color))

    def quad(self, corners, color, facing=None):
        """Single-sided polygon from explicit corners; flipped to face `facing` if given."""
        base = len(self.verts)
        for c in corners:
            self.verts.append(Vector(c))
        idx = list(range(base, base + len(corners)))
        if facing is not None:
            v0, v1, v2 = (self.verts[i] for i in idx[:3])
            if (v1 - v0).cross(v2 - v0).dot(Vector(facing)) < 0:
                idx.reverse()
        self.faces.append((idx, color))

    def mirror_x_from(self, start_v, start_f):
        """Duplicate geometry added since (start_v, start_f) mirrored across X (keeps winding outward)."""
        nv = len(self.verts)
        for v in self.verts[start_v:nv]:
            self.verts.append(Vector((-v.x, v.y, v.z)))
        off = nv - start_v
        for idx, col in self.faces[start_f:]:
            self.faces.append(([i + off for i in reversed(idx)], col))

    def build(self, name, material, target_height=None):
        if target_height:
            zmax = max(v.z for v in self.verts)
            s = target_height / zmax
            self.verts = [v * s for v in self.verts]
        bm = bmesh.new()
        bv = [bm.verts.new(v) for v in self.verts]
        uvl = bm.loops.layers.uv.new("UVMap")
        for idx, col in self.faces:
            f = bm.faces.new([bv[i] for i in idx])
            f.smooth = False
            uv = swatch_uv(col)
            for loop in f.loops:
                loop[uvl].uv = uv
        bmesh.ops.triangulate(bm, faces=bm.faces)  # explicit tris = exact budget control
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        me.materials.append(material)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def palette_material(palette_path):
    mat = bpy.data.materials.get("mat_palette")
    if mat:
        return mat
    mat = bpy.data.materials.new("mat_palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(palette_path, check_existing=True)
    tex.interpolation = "Closest"  # -> glTF sampler NEAREST
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export_glb(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_normals=True,
        export_texcoords=True, export_materials="EXPORT",
        export_image_format="AUTO", export_animations=False, export_skins=False,
        export_morph=False, export_attributes=False,
    )
