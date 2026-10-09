"""App branding (Android adaptive icon, iOS icon, portrait splash) from our own glb models.

Two stages, one file:
  1) renders (Blender 4.2, Cycles CPU, same look as render_v3.py / render_previews.py):
       blender -b --factory-startup -P tools/art/render_branding.py -- icon splash
     -> docs/art/samples/_raw/brand_*.png (transparent RGBA layers)
  2) compose (system python3 + Pillow):
       python3 tools/art/render_branding.py
     -> assets/branding/*.png and docs/art/samples/sample_branding.png

     python3 tools/art/render_branding.py splash sample   # only some steps (icons, splash, sample)

Title font: ZCOOL KuaiLe (站酷快乐体, SIL OFL 1.1) from research/third_party/fonts/ (full font; the UI subset
assets/ui/fonts/ZCOOLKuaiLe-Regular.ttf also covers 高速打僵尸).
Game title: 高速打僵尸 (confirmed). It is only baked into the splash; the icons carry no text.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(ROOT, "docs", "art", "samples", "_raw")
OUT = os.path.join(ROOT, "assets", "branding")
SAMPLES = os.path.join(ROOT, "docs", "art", "samples")
FONT = os.path.join(ROOT, "research", "third_party", "fonts", "ZCOOLKuaiLe-Regular.ttf")
TITLE = "高速打僵尸"   # confirmed game title
# splash title lines (text, font px), stacked top-down like the old two-word title; 高速 / 打僵尸
TITLE_LINES = [("高速", 200), ("打僵尸", 200)]

try:
    import bpy  # noqa: F401
    IN_BLENDER = True
except ImportError:
    IN_BLENDER = False

# --------------------------------------------------------------------------------------------- Blender stage
if IN_BLENDER:
    from mathutils import Vector
    sys.path.insert(0, HERE)
    import render_previews as rp  # noqa: E402
    import render_v3 as r3  # noqa: E402

    def _setup(transparent=True, samples=48):
        sc = r3.setup()
        sc.cycles.samples = samples
        sc.render.film_transparent = transparent
        sc.render.image_settings.color_mode = "RGBA"
        sc.render.image_settings.file_format = "PNG"
        # drop the cream ground plane from setup_scene(): layers are composited over our own backgrounds
        for o in list(bpy.data.objects):
            if o.type == "MESH" and o.name.startswith("Plane"):
                bpy.data.objects.remove(o)
        return sc

    def _emission_mat(name, hexc, strength=1.0):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs[0].default_value = rp.hexcol(hexc)
        em.inputs[1].default_value = strength
        o = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(em.outputs[0], o.inputs[0])
        return m

    def _rim_light(direction, energy, color=(0.85, 0.95, 1.0)):
        ld = bpy.data.lights.new("rim", "SUN")
        ld.color = color
        ld.energy = energy
        ld.cycles.cast_shadow = False
        ob = bpy.data.objects.new("rim", ld)
        bpy.context.scene.collection.objects.link(ob)
        ob.rotation_euler = Vector(direction).normalized().to_track_quat("-Z", "Y").to_euler()

    def icon():
        """Icon layers: tier-c soldier with gatling (faces right) and a walker head (faces left)."""
        _setup(True, 64)
        rp.instance("chr_soldier_c", 0, 0, 0)
        rp.instance("wpn_gatling", 0, 0, 0)
        rp.hide_templates()
        _rim_light((-0.6, -0.5, -0.3), 1.2)
        rp.view(os.path.join(RAW, "brand_soldier.png"), 1400, 1400, (0.12, 0.25, 1.0), 4.6, 22, 42, 25, True)
        _setup(True, 64)
        rp._cache.clear()
        rp.instance("enm_walker", 0, 0, 0)
        rp.hide_templates()
        _rim_light((0.6, -0.5, -0.3), 1.2)
        rp.view(os.path.join(RAW, "brand_zombie.png"), 1400, 1400, (0.0, 0.15, 1.05), 4.6, 12, -38, 25, True)

    def _fog_compositor(color_hex, start, depth, amount):
        sc = bpy.context.scene
        sc.view_layers[0].use_pass_mist = True
        sc.world.mist_settings.start = start
        sc.world.mist_settings.depth = depth
        sc.world.mist_settings.falloff = "LINEAR"
        sc.use_nodes = True
        nt = sc.node_tree
        nt.nodes.clear()
        rl = nt.nodes.new("CompositorNodeRLayers")
        mul = nt.nodes.new("CompositorNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = amount
        mix = nt.nodes.new("CompositorNodeMixRGB")
        mix.inputs[2].default_value = rp.hexcol(color_hex)
        sa = nt.nodes.new("CompositorNodeSetAlpha")
        comp = nt.nodes.new("CompositorNodeComposite")
        nt.links.new(rl.outputs["Mist"], mul.inputs[0])
        nt.links.new(mul.outputs[0], mix.inputs[0])
        nt.links.new(rl.outputs["Image"], mix.inputs[1])
        nt.links.new(mix.outputs[0], sa.inputs[0])
        nt.links.new(rl.outputs["Alpha"], sa.inputs[1])
        nt.links.new(sa.outputs[0], comp.inputs[0])

    def splash():
        """Portrait 1080x1920: squad close to camera, horde + elite on the bridge lane, boss silhouette far back."""
        _setup(True, 64)
        rp._cache.clear()
        rp.lane(width=7.5, y0=-8, y1=80)
        squad = [(0.0, -1.6, "c", "wpn_gatling"), (-1.2, -1.0, "c", "wpn_rocket"), (1.2, -1.0, "b", "wpn_shotgun"),
                 (-2.3, -0.2, "b", "wpn_rifle"), (2.3, -0.2, "c", "wpn_gatling"), (-0.6, 0.0, "a", "wpn_pistol"),
                 (0.6, 0.0, "a", "wpn_rifle")]
        for x, y, t, w in squad:
            rp.instance("chr_soldier_" + t, x, y, 0)
            rp.instance(w, x, y, 0)
            rp.blob(x, y + 0.05, 0.48)
        horde = [("enm_runner", -1.3, 6.0, 12), ("enm_runner", 0.6, 5.6, -8), ("enm_runner", 2.1, 6.6, -15),
                 ("enm_walker", -2.4, 8.0, 8), ("enm_walker", -0.4, 7.8, -4), ("enm_walker", 1.4, 8.4, 10),
                 ("enm_walker", 2.8, 9.4, -12), ("enm_walker", -1.6, 10.0, 4), ("enm_runner", 0.4, 10.4, 6),
                 ("enm_walker", -2.9, 11.8, 6), ("enm_walker", 2.2, 12.2, -6), ("enm_walker", -0.9, 13.0, 3),
                 ("enm_walker_lod1", 1.0, 14.6, -5), ("enm_walker_lod1", -2.3, 15.6, 8), ("enm_walker_lod1", 2.7, 16.4, -8),
                 ("enm_walker_lod1", -0.2, 17.5, 0), ("enm_walker_lod1", 1.7, 19.0, 4), ("enm_walker_lod1", -1.6, 19.6, -4)]
        for n, x, y, r in horde:
            rp.instance(n, x, y, 180 + r)
            rp.blob(x, y - 0.05, 0.55)
        rp.instance("enm_elite_brute", -0.2, 12.0, 180 + 5)
        rp.blob(-0.2, 11.9, 1.2)
        # boss: dark purple silhouette with its glowing weak-point crystals, scaled up for drama
        boss = r3.boss_inst(0.4, 30.0, 180)
        boss.scale = (1.5, 1.5, 1.5)
        sil = _emission_mat("boss_silhouette", "#5B3A86")
        mats = list(boss.data.materials)
        for i, slot in enumerate(boss.material_slots):
            slot.link = "OBJECT"
            m = mats[i]
            slot.material = m if (m and m.name.startswith("mat_weakpoint")) else sil
        rp.hide_templates()
        _rim_light((0.0, -0.6, -0.5), 0.6)
        _fog_compositor("#E9F1EC", 22.0, 40.0, 0.4)
        # low behind-and-above hero camera (game-like, a bit lower than gameplay for a poster feel)
        rp.camera((0.0, 9.0, 0.6), 25.0, 26, 4, 46)
        rp.render(os.path.join(RAW, "brand_splash.png"), 1080, 1920)

    if __name__ == "__main__":
        argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["icon", "splash"]
        for j in argv:
            globals()[j]()

# --------------------------------------------------------------------------------------------- compose stage
else:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

    INK = (26, 26, 31)          # 描边黑 #1A1A1F
    TEAL_D, TEAL, WATER = (31, 111, 107), (42, 157, 143), (92, 198, 192)
    CREAM = (241, 227, 198)
    ORANGE, ORANGE_R, FIRE = (244, 162, 97), (231, 111, 81), (255, 209, 102)

    def raw(n):
        return Image.open(os.path.join(RAW, n + ".png")).convert("RGBA")

    def trim(im):
        return im.crop(im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox())

    def outline(im, px, color=INK):
        """Thick dark outline around an RGBA layer (round dilation of the alpha)."""
        pad = px + 2
        big = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
        big.paste(im, (pad, pad), im)
        a = big.getchannel("A").point(lambda v: 255 if v > 100 else 0)
        # dilate with a disc: max filter repeated (size 3 each pass) approximates a round brush
        d = a
        for _ in range(px):
            d = d.filter(ImageFilter.MaxFilter(3))
        d = d.filter(ImageFilter.GaussianBlur(0.8))
        out = Image.new("RGBA", big.size, color + (0,))
        out.putalpha(d)
        out.alpha_composite(big)
        return out

    def radial_bg(size, inner, outer, rays=None, center=(0.5, 0.5)):
        w, h = size
        cx, cy = w * center[0], h * center[1]
        rmax = math.hypot(max(cx, w - cx), max(cy, h - cy))
        g = Image.radial_gradient("L").resize((int(rmax * 2), int(rmax * 2)))
        g = g.crop((int(rmax - cx), int(rmax - cy), int(rmax - cx) + w, int(rmax - cy) + h))
        bg = Image.composite(Image.new("RGB", size, outer), Image.new("RGB", size, inner), g)
        if rays:
            col, n, alpha = rays
            ray = Image.new("L", size, 0)
            d = ImageDraw.Draw(ray)
            R = rmax * 1.5
            for k in range(n):
                a0 = 2 * math.pi * k / n
                a1 = a0 + math.pi / n
                d.polygon([(cx, cy), (cx + R * math.cos(a0), cy + R * math.sin(a0)),
                           (cx + R * math.cos(a1), cy + R * math.sin(a1))], fill=alpha)
            bg = Image.composite(Image.new("RGB", size, col), bg, ray)
        return bg

    def burst(size, r_out, r_in, n, fill, rot=0.0):
        """Comic muzzle-flash star."""
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        c = size / 2
        pts = []
        for k in range(2 * n):
            r = r_out if k % 2 == 0 else r_in
            a = rot + math.pi * k / n
            pts.append((c + r * math.cos(a), c + r * math.sin(a)))
        ImageDraw.Draw(im).polygon(pts, fill=fill)
        return im

    def place(canvas, layer, cx, cy, h):
        """Paste layer scaled to height h, centred at (cx, cy)."""
        s = h / layer.height
        lay = layer.resize((max(1, int(layer.width * s)), int(h)), Image.LANCZOS)
        canvas.alpha_composite(lay, (int(cx - lay.width / 2), int(cy - lay.height / 2)))
        return (int(cx - lay.width / 2), int(cy - lay.height / 2), int(cx + lay.width / 2), int(cy + lay.height / 2))

    def icon_subject(S):
        """Foreground subject on an S x S transparent canvas; the subject fills ~the central 61% (264/432)."""
        sol, zom = trim(raw("brand_soldier")), trim(raw("brand_zombie"))
        # zombie: keep the head + shoulders only (top 55% of the trimmed render)
        zom = trim(zom.crop((0, 0, zom.width, int(zom.height * 0.62))))
        ol = max(2, int(S * 0.012))
        sol, zom = outline(sol, ol), outline(zom, ol)
        c = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        place(c, zom, S * 0.665, S * 0.46, S * 0.50)
        sb = place(c, sol, S * 0.375, S * 0.52, S * 0.70)
        # muzzle flash at the gatling tip (tip sits at the right edge, ~78% down the trimmed soldier render)
        fl = outline(burst(int(S * 0.24), S * 0.115, S * 0.05, 8, FIRE + (255,), 0.2), max(2, ol // 2), ORANGE_R)
        mx, my = sb[2] - S * 0.01, sb[1] + (sb[3] - sb[1]) * 0.78
        c.alpha_composite(fl, (int(mx - fl.width / 2), int(my - fl.height / 2)))
        return c

    def fit_safe(layer, S, safe):
        """Scale/centre so that the opaque bbox fits inside a centred safe square of side `safe`."""
        bb = layer.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        sub = layer.crop(bb)
        s = safe / max(sub.size)
        sub = sub.resize((int(sub.width * s), int(sub.height * s)), Image.LANCZOS)
        out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        out.alpha_composite(sub, ((S - sub.width) // 2, (S - sub.height) // 2))
        return out

    def fit_circle(layer, S, radius):
        """Scale/centre so every opaque pixel lies inside a centred circle of `radius` (Android safe zone)."""
        a = layer.getchannel("A").point(lambda v: 255 if v > 24 else 0)
        bb = a.getbbox()
        sub, am = layer.crop(bb), a.crop(bb)
        cx, cy = sub.width / 2, sub.height / 2
        px = am.load()
        rmax = 1.0
        step = max(1, sub.width // 400)
        for y in range(0, sub.height, step):
            for x in range(0, sub.width, step):
                if px[x, y]:
                    rmax = max(rmax, math.hypot(x - cx, y - cy))
        s = radius / (rmax + step)
        sub = sub.resize((int(sub.width * s), int(sub.height * s)), Image.LANCZOS)
        out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        out.alpha_composite(sub, ((S - sub.width) // 2, (S - sub.height) // 2))
        return out

    def icon_background(S):
        return radial_bg((S, S), WATER, TEAL_D, rays=(CREAM, 14, 46))

    def build_icons():
        big = icon_subject(1728)                        # 4x supersampled
        # every opaque pixel inside the r=132 safe circle (66dp of 108dp), with a 2 px margin
        fg = fit_circle(big, 1728, 1728 * 130 / 432).resize((432, 432), Image.LANCZOS)
        fg.save(os.path.join(OUT, "icon_fg.png"))
        bg = icon_background(432)
        bg.save(os.path.join(OUT, "icon_bg.png"))
        # legacy / Godot launcher icon 192: own full-bleed composition, subject bigger than the adaptive one
        main = icon_background(768).convert("RGBA")
        main.alpha_composite(fit_safe(big, 1728, 1728 * 0.88).resize((768, 768), Image.LANCZOS))
        main.resize((192, 192), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, "icon_main.png"))
        # iOS: own composition, subject bigger (no launcher mask other than iOS's rounded rect)
        ios_bg = icon_background(1024)
        ios_fg = fit_safe(big, 1728, 1728 * 0.86).resize((1024, 1024), Image.LANCZOS)
        ios = ios_bg.convert("RGBA")
        ios.alpha_composite(ios_fg)
        ios.convert("RGB").save(os.path.join(OUT, "icon_ios_1024.png"))

    def title_layer(text, size, fill_top, fill_bot, stroke):
        f = ImageFont.truetype(FONT, size)
        d = ImageDraw.Draw(Image.new("L", (1, 1)))
        l, t, r, b = d.textbbox((0, 0), text, font=f, stroke_width=stroke)
        w, h = r - l + 20, b - t + 20 + stroke
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).text((10 - l, 10 - t), text, font=f, fill=255)
        smask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(smask).text((10 - l, 10 - t), text, font=f, fill=255, stroke_width=stroke, stroke_fill=255)
        grad = Image.linear_gradient("L").resize((w, h))
        fill = Image.composite(Image.new("RGBA", (w, h), fill_bot + (255,)), Image.new("RGBA", (w, h), fill_top + (255,)), grad)
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        # drop shadow (offset stroke) + stroke + gradient fill
        sh = Image.new("RGBA", (w, h), INK + (0,))
        sh.putalpha(ImageChops.offset(smask, 0, stroke // 2 + 4))
        out.alpha_composite(sh)
        st = Image.new("RGBA", (w, h), INK + (0,))
        st.putalpha(smask)
        out.alpha_composite(st)
        fl = fill.copy()
        fl.putalpha(mask)
        out.alpha_composite(fl)
        return out

    def build_splash(path=None):
        W, H = 1080, 1920
        # sky (cream -> pale teal) over teal water: the bridge lane is rendered with a transparent film
        sky = Image.linear_gradient("L").resize((W, H))
        bg = Image.composite(Image.new("RGB", (W, H), WATER), Image.new("RGB", (W, H), (240, 236, 220)),
                             sky.point(lambda v: min(255, int(v * 1.6))))
        bg = bg.convert("RGBA")
        scene = raw("brand_splash")
        assert scene.size == (W, H)
        bg.alpha_composite(scene)
        # cream haze band behind the title for readability
        haze = Image.new("L", (W, H), 0)
        ImageDraw.Draw(haze).rectangle((0, 0, W, 160), fill=150)
        haze = haze.filter(ImageFilter.GaussianBlur(80))
        bg = Image.composite(Image.new("RGBA", (W, H), (244, 235, 217, 255)), bg, haze)
        assert "".join(t for t, _ in TITLE_LINES) == TITLE
        y = 300
        for w, size in TITLE_LINES:
            t = title_layer(w, size, FIRE, ORANGE_R, 16)
            if t.width > 860:
                t = t.resize((860, int(t.height * 860 / t.width)), Image.LANCZOS)
            bg.alpha_composite(t, ((W - t.width) // 2, y))
            y += t.height - 30
        bg.convert("RGB").save(path or os.path.join(OUT, "splash_1080x1920.png"))

    def build_sample():
        names = ["icon_fg", "icon_bg", "icon_main", "icon_ios_1024", "splash_1080x1920"]
        im = {n: Image.open(os.path.join(OUT, n + ".png")) for n in names}
        BGc, SUB = (244, 235, 217), (110, 98, 84)
        Wc, Hc = 1080 + 1024 + 432 * 2 + 200, 1920 + 160
        c = Image.new("RGB", (Wc, Hc), BGc)
        d = ImageDraw.Draw(c)
        fb = ImageFont.truetype(FONT, 44)
        fs = ImageFont.truetype(FONT, 22)
        d.text((40, 24), "Branding (actual size)  -  title 高速打僵尸 (splash only; icons have no text)", fill=INK, font=fb)
        x0, y0 = 40, 120
        c.paste(im["splash_1080x1920"], (x0, y0))
        d.text((x0, y0 - 30), "splash_1080x1920.png  (dashed: central safe area 900x1560)", fill=SUB, font=fs)
        sx, sy = x0 + 90, y0 + 180
        for k in range(0, 900, 24):
            d.line((sx + k, sy, sx + k + 12, sy), fill=ORANGE_R, width=2)
            d.line((sx + k, sy + 1560, sx + k + 12, sy + 1560), fill=ORANGE_R, width=2)
        for k in range(0, 1560, 24):
            d.line((sx, sy + k, sx, sy + k + 12), fill=ORANGE_R, width=2)
            d.line((sx + 900, sy + k, sx + 900, sy + k + 12), fill=ORANGE_R, width=2)
        x1 = x0 + 1080 + 40
        c.paste(im["icon_ios_1024"], (x1, y0))
        d.text((x1, y0 - 30), "icon_ios_1024.png", fill=SUB, font=fs)
        x2 = x1 + 1024 + 40
        checker = Image.new("RGB", (432, 432), (255, 255, 255))
        cd = ImageDraw.Draw(checker)
        for i in range(0, 432, 24):
            for j in range(0, 432, 24):
                if (i // 24 + j // 24) % 2:
                    cd.rectangle((i, j, i + 23, j + 23), fill=(220, 220, 220))
        checker.paste(im["icon_fg"], (0, 0), im["icon_fg"])
        ImageDraw.Draw(checker).ellipse((84, 84, 348, 348), outline=ORANGE_R, width=2)
        c.paste(checker, (x2, y0))
        d.text((x2, y0 - 30), "icon_fg.png (circle: 264 safe zone)", fill=SUB, font=fs)
        c.paste(im["icon_bg"], (x2 + 432 + 20, y0))
        d.text((x2 + 452, y0 - 30), "icon_bg.png", fill=SUB, font=fs)
        # adaptive previews: circle + squircle masks (launcher shows central 72dp of 108dp)
        full = im["icon_bg"].convert("RGBA")
        full.alpha_composite(im["icon_fg"])
        view = full.crop((72, 72, 360, 360))
        yy = y0 + 432 + 70
        d.text((x2, yy - 30), "launcher masks (288 view)", fill=SUB, font=fs)
        for i, kind in enumerate(("circle", "squircle", "square")):
            m = Image.new("L", (288, 288), 0)
            md = ImageDraw.Draw(m)
            if kind == "circle":
                md.ellipse((0, 0, 287, 287), fill=255)
            elif kind == "squircle":
                md.rounded_rectangle((0, 0, 287, 287), 70, fill=255)
            else:
                md.rectangle((0, 0, 287, 287), fill=255)
            v = view.resize((200, 200), Image.LANCZOS)
            c.paste(v, (x2 + i * 220, yy), m.resize((200, 200), Image.LANCZOS))
        yy += 260
        c.paste(im["icon_main"], (x2, yy))
        d.text((x2, yy - 30), "icon_main.png 192", fill=SUB, font=fs)
        # small sizes, round masked, on light and dark wallpaper
        for j, wall in enumerate(((244, 235, 217), (40, 44, 52))):
            bx, by = x2 + 230, yy + j * 100
            d.rectangle((bx, by, bx + 600, by + 90), fill=wall)
            for k, s in enumerate((48, 72, 96)):
                m = Image.new("L", (s, s), 0)
                ImageDraw.Draw(m).ellipse((0, 0, s - 1, s - 1), fill=255)
                c.paste(view.resize((s, s), Image.LANCZOS), (bx + 20 + k * 130, by + 45 - s // 2), m)
                if j == 0:
                    d.text((bx + 20 + k * 130, by - 26), "%d px" % s, fill=SUB, font=fs)
        # 48 px ios + main
        yy += 230
        d.text((x2, yy), "48 px: ios / main / adaptive round", fill=SUB, font=fs)
        c.paste(im["icon_ios_1024"].resize((48, 48), Image.LANCZOS), (x2, yy + 36))
        c.paste(im["icon_main"].resize((48, 48), Image.LANCZOS), (x2 + 70, yy + 36))
        m = Image.new("L", (48, 48), 0)
        ImageDraw.Draw(m).ellipse((0, 0, 47, 47), fill=255)
        c.paste(view.resize((48, 48), Image.LANCZOS), (x2 + 140, yy + 36), m)
        d.text((x1, Hc - 40), "renders: our own glb models (tools/art/render_branding.py)  |  font: ZCOOL KuaiLe, SIL OFL 1.1",
               fill=SUB, font=fs)
        c.save(os.path.join(SAMPLES, "sample_branding.png"))

    if __name__ == "__main__":
        os.makedirs(OUT, exist_ok=True)
        steps = sys.argv[1:] or ["icons", "splash", "sample"]
        for step in steps:
            {"icons": build_icons, "splash": build_splash, "sample": build_sample}[step]()
        print("ok", " ".join(steps))
