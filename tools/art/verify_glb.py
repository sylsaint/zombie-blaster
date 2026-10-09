"""Verify exported glbs without Blender: triangle count, bounds (glTF Y-up), facing, UV->swatch centres,
materials/samplers. Usage: python3 tools/art/verify_glb.py assets/models/*.glb

v0.4 checks (exit code 1 on any FAIL): triangle budget per asset, exactly one material "mat_palette", UVs on
swatch centres, NO vertex colour attribute (COLOR_n: the engine writes its smoothed outline normals into vertex
colours on import), hard edges / flat shading (all 3 vertex normals of every triangle equal the face normal),
forward reach (-Z) limit for enemies."""
import json
import os
import struct
import sys

import numpy as np

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load(path):
    data = open(path, "rb").read()
    assert data[:4] == b"glTF"
    off, js, binc = 12, None, None
    while off < len(data):
        ln, typ = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + ln]
        if typ == 0x4E4F534A:
            js = json.loads(chunk)
        elif typ == 0x004E4942:
            binc = chunk
        off += 8 + ln
    return js, binc


def acc(js, binc, i):
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    n = NC[a["type"]]
    dt = CT[a["componentType"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0)
    if stride and stride != n * np.dtype(dt).itemsize:
        raise NotImplementedError("interleaved")
    arr = np.frombuffer(binc, dtype=dt, count=a["count"] * n, offset=start)
    return arr.reshape(-1, n) if n > 1 else arr


BUDGET = {"chr_soldier_": 450, "wpn_": 120, "enm_walker_lod1": 200, "enm_runner_lod1": 200, "enm_walker": 450,
          "enm_runner": 450, "enm_elite_brute": 1500, "boss_": 5000}
# assets/textures/palette.png is 256x256, 32px cells.
PALETTE_COLS, PALETTE_ROWS = 8, 8
REACH = {"enm_walker": 0.6, "enm_runner": 0.6, "enm_elite_brute": 0.9}


def limit(table, name):
    for k in sorted(table, key=len, reverse=True):
        if name.startswith(k):
            return table[k]
    return None


def main(paths):
    fails = []
    for p in paths:
        js, binc = load(p)
        tris, P, UV, UV2 = 0, [], [], []
        for node in js["nodes"]:
            assert "rotation" not in node and "scale" not in node and "translation" not in node, \
                "unapplied transform on node %s" % node.get("name")
        mats = set()
        attrs = set()
        flat_bad, flat_total, degen = 0, 0, 0
        for m in js["meshes"]:
            for pr in m["primitives"]:
                assert pr.get("mode", 4) == 4
                idx = acc(js, binc, pr["indices"])
                tris += len(idx) // 3
                attrs |= set(pr["attributes"])
                pos = acc(js, binc, pr["attributes"]["POSITION"])
                if "NORMAL" in pr["attributes"]:
                    nrm = acc(js, binc, pr["attributes"]["NORMAL"])
                    t = np.asarray(idx).reshape(-1, 3)
                    fn = np.cross(pos[t[:, 1]] - pos[t[:, 0]], pos[t[:, 2]] - pos[t[:, 0]])
                    degen += int((np.linalg.norm(fn, axis=1) < 1e-9).sum())
                    fn /= np.linalg.norm(fn, axis=1, keepdims=True) + 1e-12
                    for k in range(3):
                        flat_bad_k = np.einsum("ij,ij->i", nrm[t[:, k]], fn) < 0.999
                        flat_bad += int(flat_bad_k.sum())
                    flat_total += 3 * len(t)
                P.append(pos)
                UV.append(acc(js, binc, pr["attributes"]["TEXCOORD_0"]))
                if "TEXCOORD_1" in pr["attributes"]:
                    UV2.append(acc(js, binc, pr["attributes"]["TEXCOORD_1"]))
                mats.add(pr.get("material"))
        prim_count = len(UV)
        uv2_prims = len(UV2)
        P, UV = np.vstack(P), np.vstack(UV)
        mn, mx = P.min(0), P.max(0)
        # glTF UV origin top-left. 256x256 palette, 8x8 cells:
        # swatch centre u=(c+.5)/8, v=(r+.5)/8. Rows 0-3 stay in v 0..0.5.
        cols = np.round(UV[:, 0] * PALETTE_COLS - 0.5, 4)
        rows = np.round(UV[:, 1] * PALETTE_ROWS - 0.5, 4)
        on_centre = np.all(np.abs(cols - np.round(cols)) < 1e-3) and np.all(np.abs(rows - np.round(rows)) < 1e-3)
        sw = sorted(set(zip(rows.astype(int).tolist(), cols.astype(int).tolist())))
        samplers = js.get("samplers", [])
        print("%s" % p)
        print("  triangles: %d   verts: %d   meshes: %d   materials: %d (%s)" % (
            tris, len(P), len(js["meshes"]), len(mats), [js["materials"][i]["name"] for i in mats]))
        print("  bounds X %.3f..%.3f  Y %.3f..%.3f  Z %.3f..%.3f" % (mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]))
        print("  size (w x h x d): %.3f x %.3f x %.3f m ; feet at Y=%.3f" % (*(mx - mn)[[0, 1, 2]], mn[1]))
        # facing: more geometry toward -Z means the character faces -Z (arms/head/gun reach forward)
        print("  max forward reach (-Z) %.3f m ; max behind (+Z) %.3f m ; max side |X| %.3f m" % (
            -mn[2], mx[2], np.abs(P[:, 0]).max()))
        print("  footprint half-width |X| max %.3f m (left %.3f / right %.3f) ; half-depth %.3f m" % (
            np.abs(P[:, 0]).max(), -mn[0], mx[0], max(-mn[2], mx[2])))
        print("  centroid Z %.3f (negative => reaches toward -Z)" % P[:, 2].mean())
        print("  UVs on swatch centres: %s ; swatches (row,col): %s" % (on_centre, sw))
        print("  samplers: %s ; images: %d" % (samplers, len(js.get("images", []))))
        name = p.rsplit("/", 1)[-1][:-4]
        colours = sorted(a for a in attrs if a.startswith("COLOR_"))
        print("  attributes: %s" % sorted(attrs))
        checks = []
        b = limit(BUDGET, name)
        if b:
            checks.append(("tris %d <= %d" % (tris, b), tris <= b))
        names = [js["materials"][i]["name"] for i in mats if i is not None]
        if name.startswith("boss_"):
            # boss exception (tech lead): body mesh on mat_palette + separate mesh node "weakpoint" on mat_weakpoint
            nm = {}
            for node in js["nodes"]:
                if "mesh" in node:
                    nm[node.get("name")] = sorted({js["materials"][pr["material"]]["name"]
                                                   for pr in js["meshes"][node["mesh"]]["primitives"]})
            body = [k for k in nm if k != "weakpoint"]
            checks.append(("boss: nodes %s" % nm, len(nm) == 2 and nm.get("weakpoint") == ["mat_weakpoint"]
                           and len(body) == 1 and nm[body[0]] == ["mat_palette"]))
        else:
            checks.append(("single material mat_palette", len(mats) == 1 and names == ["mat_palette"]))
        checks.append(("UVs on swatch centres", bool(on_centre)))
        checks.append(("no vertex colours (COLOR_n) %s" % (colours or ""), not colours))
        checks.append(("flat shading: %d/%d vertex normals off the face normal" % (flat_bad, flat_total),
                       "NORMAL" in attrs and flat_bad == 0))
        checks.append(("degenerate (zero-area) triangles: %d" % degen, degen == 0))
        r = limit(REACH, name)
        if r:
            checks.append(("forward reach %.3f <= %.2f m" % (-mn[2], r), -mn[2] <= r + 1e-4))
        vat_path = p.rsplit("/", 1)[0] + "/anim/" + name + "_vat.json"
        has_vat = os.path.isfile(vat_path)
        if has_vat:
            spec = json.load(open(vat_path))
            width = int(spec["width"])
            rows = int(spec.get("rows_per_frame", 1))
            ok_uv2 = uv2_prims == prim_count and width > 0
            if ok_uv2:
                uv2 = np.vstack(UV2)
                cols = np.rint(uv2[:, 0] * width - 0.5).astype(np.int32)
                expected_u = (cols.astype(np.float64) + 0.5) / float(width)
                ok_uv2 = bool(np.all(np.abs(uv2[:, 0] - expected_u) < 1e-4))
                ok_uv2 = ok_uv2 and int(cols.min()) >= 0 and int(cols.max()) < width
                if rows == 1:
                    ok_uv2 = ok_uv2 and bool(np.all(np.abs(uv2[:, 1] - 0.5) < 1e-4))
            checks.append(("UV2 column matches %s" % vat_path, ok_uv2))
        elif UV2:
            checks.append(("UV2 without a VAT json", False))
        for label, ok in checks:
            print("  [%s] %s" % ("PASS" if ok else "FAIL", label))
            if not ok:
                fails.append("%s: %s" % (name, label))
    print("\nSUMMARY: %d files, %s" % (len(paths), "ALL PASS" if not fails else "FAILS:\n  " + "\n  ".join(fails)))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
