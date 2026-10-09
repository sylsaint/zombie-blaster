"""Measure triangle counts / rig / anims / textures of third-party glTF models.
Usage: blender -b --factory-startup -P tools/art/research/measure_tris.py -- out.json file1.glb file2.gltf ..."""
import bpy, sys, json, os
argv = sys.argv[sys.argv.index("--") + 1:]
out, files = argv[0], argv[1:]
res = []
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.gltf(filepath=f)
    except Exception as e:
        res.append({"file": f, "error": str(e)}); continue
    parts = {}; tris = 0; meshes = 0; mats = set(); imgs = {}
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or any(c.name == "glTF_not_exported" for c in o.users_collection):
            continue
        meshes += 1
        t = sum(len(p.vertices) - 2 for p in o.data.polygons)
        parts[o.name] = t
        tris += t
        for m in o.data.materials:
            if m:
                mats.add(m.name)
                if m.use_nodes:
                    for n in m.node_tree.nodes:
                        if n.type == "TEX_IMAGE" and n.image:
                            imgs[n.image.name] = list(n.image.size)
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    bones = sum(len(a.data.bones) for a in arms)
    dims = None
    import mathutils
    pts = []
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name in parts:
            pts += [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    if pts:
        dims = [round(max(p[i] for p in pts) - min(p[i] for p in pts), 3) for i in range(3)]
    res.append({"file": os.path.relpath(f, "/workspace/zombie-blaster-art"), "tris": tris, "parts": parts, "meshes": meshes,
                "bones": bones, "actions": [a.name for a in bpy.data.actions],
                "materials": sorted(mats), "textures": imgs, "dims_xyz": dims})
json.dump(res, open(out, "w"), indent=1)
print("WROTE", out, len(res))
