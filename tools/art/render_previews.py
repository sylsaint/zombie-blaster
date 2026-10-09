"""Render preview images of the exported glbs (loads the .glb files, so it also checks orientation).

Usage: blender -b --factory-startup -P tools/art/render_previews.py
v2: writes raw views to docs/art/samples/_raw/ ; tools/art/compose_previews.py assembles final PNGs.
Cycles CPU (no GPU/EGL on the build box). Look: one non-shadowing warm sun from back-left-top,
cyan ambient, flat cream background (#F4EBD9), blob shadows like the game.
"""
import math
import os
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MODELS = os.path.join(ROOT, "assets", "models")
RAW = os.path.join(ROOT, "docs", "art", "samples", "_raw")
os.makedirs(RAW, exist_ok=True)


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h, a=1.0):
    h = h.lstrip("#")
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (a,)


BG = "#F4EBD9"


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 2
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.film_transparent = False
    # world: camera rays see flat cream; lighting sees a cool cyan ambient
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    lp = nt.nodes.new("ShaderNodeLightPath")
    amb = nt.nodes.new("ShaderNodeBackground")
    amb.inputs[0].default_value = hexcol("#CFE6EE")
    amb.inputs[1].default_value = 0.55
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs[0].default_value = hexcol(BG)
    bg.inputs[1].default_value = 1.0
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(amb.outputs[0], mix.inputs[1])
    nt.links.new(bg.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    # sun: warm white from back-left-top (camera sits behind the squad at -Y)
    ld = bpy.data.lights.new("sun", "SUN")
    ld.color = (1.0, 0.957, 0.878)
    ld.energy = 2.6
    ld.angle = math.radians(2)
    try:
        ld.use_shadow = False
    except AttributeError:
        pass
    if hasattr(ld, "cycles") and hasattr(ld.cycles, "cast_shadow"):
        ld.cycles.cast_shadow = False
    sun = bpy.data.objects.new("sun", ld)
    sc.collection.objects.link(sun)
    d = Vector((0.55, 0.45, -0.70)).normalized()   # light travels +x(right) +y(forward) down
    sun.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    # ground: shadeless cream so it melts into the background
    bpy.ops.mesh.primitive_plane_add(size=200)
    g = bpy.context.object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gn = gm.node_tree
    gn.nodes.clear()
    em = gn.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = hexcol(BG)
    o = gn.nodes.new("ShaderNodeOutputMaterial")
    gn.links.new(em.outputs[0], o.inputs[0])
    g.data.materials.append(gm)
    return sc


def blob_material():
    m = bpy.data.materials.get("blob")
    if m:
        return m
    m = bpy.data.materials.new("blob")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    tc = nt.nodes.new("ShaderNodeTexCoord")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.45
    ramp.color_ramp.elements[1].color = (0.32, 0.32, 0.32, 1)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = hexcol("#B9A88A")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tc.outputs["Object"], grad.inputs[0])
    nt.links.new(grad.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], o.inputs[0])
    return m


def blob(x, y, r):
    bpy.ops.mesh.primitive_circle_add(vertices=24, radius=1.0, fill_type="NGON", location=(x, y, 0.004))
    ob = bpy.context.object
    ob.scale = (r, r, 1)
    ob.data.materials.append(blob_material())
    ob.visible_shadow = False
    return ob


_cache = {}


def load(name):
    """Import glb once; return its mesh object (template)."""
    if name in _cache:
        return _cache[name]
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"))
    ob = [o for o in bpy.context.selected_objects if o.type == "MESH"][0]
    _cache[name] = ob
    return ob


def instance(name, x, y, rot_z_deg=0.0):
    src = load(name)
    ob = bpy.data.objects.new(name + "_inst", src.data)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (x, y, 0)
    ob.rotation_euler = (0, 0, math.radians(rot_z_deg))
    return ob


def camera(target, dist, pitch_deg, yaw_deg, fov_deg, front=False):
    th, ph = math.radians(pitch_deg), math.radians(yaw_deg)
    sgn = 1 if front else -1
    t = Vector(target)
    loc = t + dist * Vector((math.sin(ph) * math.cos(th), sgn * math.cos(ph) * math.cos(th), math.sin(th)))
    cd = bpy.data.cameras.new("cam")
    cd.sensor_fit = "VERTICAL"
    cd.angle_y = math.radians(fov_deg)
    cam = bpy.data.objects.new("cam", cd)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (t - loc).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def render(path, w, h):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def hide_templates():
    for o in _cache.values():
        o.hide_render = True
        o.hide_viewport = True


def instance_centered(name, x, y, z, rot_z=0.0, rot_x=0.0):
    """Instance a mesh re-centred on its bbox centre (used for the weapon strip)."""
    src = load(name)
    cs = [v.co for v in src.data.vertices]
    c = Vector([(min(v[i] for v in cs) + max(v[i] for v in cs)) / 2 for i in range(3)])
    ob = bpy.data.objects.new(name + "_c", src.data)
    bpy.context.scene.collection.objects.link(ob)
    from mathutils import Matrix
    ob.matrix_world = (Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(rot_z), 4, "Z") @
                       Matrix.Rotation(math.radians(rot_x), 4, "X") @ Matrix.Translation(-c))
    return ob


def lane(width=7.5, y0=-6, y1=30):
    """Hint of a bridge lane: flat warm deck + low teal rails (shadeless-ish deck)."""
    m = bpy.data.materials.new("deck")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = hexcol("#E8DCC2")
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], o.inputs[0])
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, (y0 + y1) / 2, 0.002))
    d = bpy.context.object
    d.scale = (width, y1 - y0, 1)
    d.data.materials.append(m)
    # deck seams
    sm = bpy.data.materials.new("seam")
    sm.use_nodes = True
    sn = sm.node_tree
    sn.nodes.clear()
    e2 = sn.nodes.new("ShaderNodeEmission")
    e2.inputs[0].default_value = hexcol("#DCCDAF")
    o2 = sn.nodes.new("ShaderNodeOutputMaterial")
    sn.links.new(e2.outputs[0], o2.inputs[0])
    for k in range(int(y0), int(y1), 2):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, k, 0.003))
        p = bpy.context.object
        p.scale = (width, 0.05, 1)
        p.data.materials.append(sm)
    rail = bpy.data.materials.new("rail")
    rail.use_nodes = True
    rail.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = hexcol("#2A9D8F")
    rail.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(sx * (width / 2 + 0.1), (y0 + y1) / 2, 0.35))
        r = bpy.context.object
        r.scale = (0.12, y1 - y0, 0.12)
        r.data.materials.append(rail)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(sx * (width / 2 + 0.1), (y0 + y1) / 2, 0.06))
        r = bpy.context.object
        r.scale = (0.3, y1 - y0, 0.12)
        r.data.materials.append(rail)
        for k in range(int(y0), int(y1), 3):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(sx * (width / 2 + 0.1), k, 0.2))
            r = bpy.context.object
            r.scale = (0.1, 0.1, 0.4)
            r.data.materials.append(rail)


def view(path, w, h, target, dist, pitch, yaw, fov, front):
    if bpy.context.scene.camera:
        bpy.data.objects.remove(bpy.context.scene.camera)
    camera(target, dist, pitch, yaw, fov, front=front)
    render(path, w, h)


def tiers():
    setup_scene()
    _cache.clear()
    # front camera looks toward -Y, so +X is screen-left: a | b | c reads left to right
    for x, body, wpn in ((1.1, "chr_soldier_a", "wpn_pistol"), (0.0, "chr_soldier_b", "wpn_rifle"),
                         (-1.1, "chr_soldier_c", "wpn_gatling")):
        instance(body, x, 0, 0)
        instance(wpn, x, 0, 0)
        blob(x, 0.05, 0.5)
    hide_templates()
    view(os.path.join(RAW, "tiers_front.png"), 1600, 1000, (0, 0, 0.82), 6.2, 12, 28, 26, True)
    view(os.path.join(RAW, "tiers_game.png"), 1600, 1000, (0, 0.2, 0.8), 6.2, 50, 15, 26, False)


def weapons_strip():
    setup_scene()
    _cache.clear()
    names = ["wpn_pistol", "wpn_rifle", "wpn_shotgun", "wpn_gatling", "wpn_rocket"]
    for i, n in enumerate(names):
        instance_centered(n, 2.8 - i * 1.4, 0, 0.5, rot_z=90)
    hide_templates()
    view(os.path.join(RAW, "weapons.png"), 1600, 360, (-0.1, 0, 0.5), 8.5, 16, 0, 10.5, True)


def zombies():
    setup_scene()
    _cache.clear()
    for x, n, r in ((1.6, "enm_walker", 0), (0.35, "enm_runner", 0), (-1.45, "enm_elite_brute", 0)):
        instance(n, x, 0, r)
        blob(x, 0.0, 0.55 if "elite" not in n else 1.05)
    hide_templates()
    view(os.path.join(RAW, "zombies_front.png"), 1600, 1000, (0.0, 0, 1.15), 8.4, 12, 28, 28, True)
    view(os.path.join(RAW, "zombies_game.png"), 1600, 1000, (0.0, 0, 1.0), 8.4, 50, 15, 28, True)


def lods():
    setup_scene()
    _cache.clear()
    for x, n in ((1.6, "enm_walker"), (0.6, "enm_walker_lod1"), (-0.5, "enm_runner"), (-1.5, "enm_runner_lod1")):
        instance(n, x, 0, 0)
        blob(x, 0.0, 0.5)
    hide_templates()
    view(os.path.join(RAW, "lods.png"), 1000, 420, (0.05, 0, 0.9), 9.0, 30, 0, 18, True)


def lineup_v3():
    setup_scene()
    _cache.clear()
    lane()
    # squad of 10: mostly tier b (rifle / shotgun), two tier c (gatling / rocket)
    squad = [(-1.65, 0.0, "b", "wpn_rifle"), (-0.55, 0.0, "b", "wpn_shotgun"), (0.55, 0.0, "b", "wpn_rifle"),
             (1.65, 0.0, "b", "wpn_shotgun"), (-1.1, 1.05, "b", "wpn_rifle"), (0.0, 1.05, "c", "wpn_gatling"),
             (1.1, 1.05, "b", "wpn_rifle"), (-1.1, 2.1, "b", "wpn_shotgun"), (0.0, 2.1, "c", "wpn_rocket"),
             (1.1, 2.1, "b", "wpn_rifle")]
    for x, y, t, w in squad:
        jx = 0.05 * math.sin(x * 7 + y * 3)
        instance("chr_soldier_" + t, x + jx, y, 0)
        instance(w, x + jx, y, 0)
        blob(x + jx, y + 0.05, 0.48)
    runners = [(-1.4, 5.2, 12), (0.25, 4.9, -8), (1.7, 5.4, -15), (-0.5, 5.8, 6)]
    for x, y, r in runners:
        instance("enm_runner", x, y, 180 + r)
        blob(x, y, 0.42)
    walkers = [(-2.0, 6.9, 8), (-0.85, 7.1, -6), (0.9, 6.9, 10), (2.0, 7.2, -12), (-1.5, 8.2, 4), (1.5, 8.3, -4)]
    for x, y, r in walkers:
        instance("enm_walker", x, y, 180 + r)
        blob(x, y - 0.05, 0.55)
    instance("enm_elite_brute", 0.05, 9.2, 180)
    blob(0.05, 9.1, 1.2)
    hide_templates()
    camera((0, 4.4, 0.5), 11.6, 50, 0, 50)
    render(os.path.join(RAW, "lineup_v3.png"), 1080, 1350)


if __name__ == "__main__":
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    which = argv or ["tiers", "weapons", "zombies", "lods", "lineup_v3"]
    if "tiers" in which:
        tiers()
    if "weapons" in which:
        weapons_strip()
    if "zombies" in which:
        zombies()
    if "lods" in which:
        lods()
    if "lineup_v3" in which:
        lineup_v3()
