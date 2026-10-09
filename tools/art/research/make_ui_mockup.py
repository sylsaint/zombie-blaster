"""UI mockups (portrait 1080x1920) built from Kenney UI Pack / Game Icons sprites (CC0) + 站酷快乐体 (OFL).
Numbers come from the design docs: squad-and-gates.md (M1 skill cards) and progression.md / enemies.md
(level 3 boss 27000 HP, phase 60%, 1.5 s invulnerable roar; rewards).
Usage: python3 tools/art/research/make_ui_mockup.py
Writes docs/art/research/ui_mockup.png (battle: boss bar + pick-one-of-three) and
       docs/art/research/ui_mockup_result.png (level result + failure variant)."""
import math, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TP = os.path.join(ROOT, "research/third_party")
UI = os.path.join(TP, "kenney/ui-pack/PNG")
IC = os.path.join(TP, "kenney/game-icons/PNG/White/2x")
BG = os.path.join(ROOT, "docs/art/research/_raw/ui_bg.png")
OUTDIR = os.path.join(ROOT, "docs/art/research")
KUAILE = os.path.join(TP, "fonts/ZCOOLKuaiLe-Regular.ttf")
NOTO = os.path.join(TP, "fonts/NotoSansSC-VF.ttf")

INK = (26, 26, 31)
CREAM = (247, 244, 236)
GOLD = (242, 193, 78)
ORANGE = (244, 162, 97)
RED = (200, 66, 59)
DRED = (126, 31, 35)
CYAN = (76, 201, 240)
WHITE = (255, 255, 255)


def fk(size):
    return ImageFont.truetype(KUAILE, size)


def fn(size, weight="Bold"):
    f = ImageFont.truetype(NOTO, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def sprite(rel):
    return Image.open(os.path.join(UI, rel)).convert("RGBA")


def icon(name, size):
    return Image.open(os.path.join(IC, name)).convert("RGBA").resize((size, size), Image.LANCZOS)


def nine(src, w, h, b=12, s=3):
    """9-slice a small Kenney sprite to w x h with corners scaled s times."""
    sw, sh = src.size
    B = b * s
    out = Image.new("RGBA", (w, h))
    def piece(box, size):
        return src.crop(box).resize(size, Image.LANCZOS)
    xs = [(0, b, 0, B), (b, sw - b, B, w - B), (sw - b, sw, w - B, w)]
    ys = [(0, b, 0, B), (b, sh - b, B, h - B), (sh - b, sh, h - B, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 > dx0 and dy1 > dy0:
                out.alpha_composite(piece((sx0, sy0, sx1, sy1), (dx1 - dx0, dy1 - dy0)), (dx0, dy0))
    return out


def text_c(d, cx, y, s, f, fill=WHITE, stroke=0, sfill=INK):
    w = d.textlength(s, font=f)
    d.text((cx - w / 2, y), s, font=f, fill=fill, stroke_width=stroke, stroke_fill=sfill)


def note(img, x, y, s, anchor_pt=None):
    """Designer annotation tag (not part of the game UI)."""
    d = ImageDraw.Draw(img)
    f = fn(22)
    w = d.textlength(s, font=f)
    d.rounded_rectangle((x, y, x + w + 24, y + 38), radius=10, fill=(239, 71, 111, 235))
    d.text((x + 12, y + 5), s, font=f, fill=WHITE)
    if anchor_pt:
        d.line((x + 12, y + 19, anchor_pt[0], anchor_pt[1]), fill=(239, 71, 111), width=3)
        d.ellipse((anchor_pt[0] - 6, anchor_pt[1] - 6, anchor_pt[0] + 6, anchor_pt[1] + 6), fill=(239, 71, 111))


def panel(img, box, alpha=180, r=28):
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ov).rounded_rectangle(box, radius=r, fill=(26, 26, 31, alpha))
    img.alpha_composite(ov)


# ---------------------------------------------------------------- boss bar
def boss_bar(img, x, y, w, frac, name, lvl_txt, hp_txt, ticks, shielded=False, scale=1.0):
    d = ImageDraw.Draw(img)
    h = int(150 * scale)
    panel(img, (x, y, x + w, y + h), 190, int(26 * scale))
    # skull badge (Kenney red round button + exclamation icon)
    bs = int(96 * scale)
    badge = sprite("Grey/Default/button_round_depth_flat.png" if shielded else "Red/Default/button_round_depth_gradient.png").resize((bs, bs), Image.LANCZOS)
    img.alpha_composite(badge, (x + int(16 * scale), y + int(26 * scale)))
    ic = icon("locked.png" if shielded else "warning.png", int(56 * scale))
    img.alpha_composite(ic, (x + int(16 * scale) + (bs - ic.width) // 2, y + int(26 * scale) + (bs - ic.height) // 2 - int(3 * scale)))
    tx = x + int(128 * scale)
    d.text((tx, y + int(12 * scale)), name, font=fk(int(50 * scale)), fill=(200, 200, 200) if shielded else WHITE,
           stroke_width=max(2, int(4 * scale)), stroke_fill=INK)
    nw = d.textlength(name, font=fk(int(50 * scale)))
    d.text((tx + nw + int(16 * scale), y + int(30 * scale)), lvl_txt, font=fn(int(24 * scale)), fill=(230, 220, 200))
    hpw = d.textlength(hp_txt, font=fk(int(34 * scale)))
    d.text((x + w - hpw - int(22 * scale), y + int(22 * scale)), hp_txt, font=fk(int(34 * scale)), fill=WHITE,
           stroke_width=max(2, int(3 * scale)), stroke_fill=INK)
    # bar
    bx0, by0 = tx, y + int(84 * scale)
    bx1, by1 = x + w - int(22 * scale), y + int(126 * scale)
    r = (by1 - by0) // 2
    d.rounded_rectangle((bx0 - 4, by0 - 4, bx1 + 4, by1 + 4), radius=r + 4, fill=INK)
    d.rounded_rectangle((bx0, by0, bx1, by1), radius=r, fill=(70, 30, 34))
    fx = bx0 + int((bx1 - bx0) * frac)
    if shielded:
        d.rounded_rectangle((bx0, by0, fx, by1), radius=r, fill=(150, 150, 158))
        # diagonal hatch = invulnerable
        hatch = Image.new("RGBA", img.size, (0, 0, 0, 0))
        hd = ImageDraw.Draw(hatch)
        for k in range(bx0 - 60, fx, 22):
            hd.line((k, by1, k + (by1 - by0), by0), fill=(255, 255, 255, 110), width=6)
        mask = Image.new("L", img.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((bx0, by0, fx, by1), radius=r, fill=255)
        img.paste(hatch, (0, 0), Image.composite(hatch, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask).split()[3])
    else:
        d.rounded_rectangle((bx0, by0, fx, by1), radius=r, fill=RED)
        d.rounded_rectangle((bx0 + 6, by0 + 5, fx - 6, by0 + (by1 - by0) // 2 - 1), radius=r // 2, fill=(232, 110, 100))
        # recent damage chunk (white trail)
        d.rectangle((fx, by0 + 3, min(bx1 - 2, fx + int(30 * scale)), by1 - 3), fill=(255, 230, 220))
    d = ImageDraw.Draw(img)
    for t in ticks:
        tx_ = bx0 + int((bx1 - bx0) * t)
        d.polygon([(tx_ - int(10 * scale), by0 - int(16 * scale)), (tx_ + int(10 * scale), by0 - int(16 * scale)), (tx_, by0 - 2)], fill=GOLD, outline=INK)
        d.line((tx_, by0, tx_, by1), fill=INK, width=max(3, int(5 * scale)))
        d.text((tx_ - int(22 * scale), by1 + int(2 * scale)), f"{int(t * 100)}%", font=fn(int(18 * scale)), fill=(240, 230, 210))
    if shielded:
        sh = sprite("Blue/Default/button_round_depth_gradient.png").resize((int(74 * scale), int(74 * scale)), Image.LANCZOS)
        cx = bx0 + (fx - bx0) // 2
        img.alpha_composite(sh, (cx - sh.width // 2, by0 + (by1 - by0) // 2 - sh.height // 2))
        d.text((cx + sh.width // 2 + 10, by0 + (by1 - by0) // 2 - int(19 * scale)), "无敌 1.5s", font=fk(int(34 * scale)),
               fill=WHITE, stroke_width=3, stroke_fill=INK)
        ic2 = icon("locked.png", int(40 * scale))
        img.alpha_composite(ic2, (cx - ic2.width // 2, by0 + (by1 - by0) // 2 - ic2.height // 2 - 2))
    return h


# ---------------------------------------------------------------- icons drawn for the skill cards
def draw_bullet(d, x, y, ang, L=46, W=18, col=GOLD):
    ca, sa = math.cos(ang), math.sin(ang)
    def P(u, v):
        return (x + u * ca - v * sa, y + u * sa + v * ca)
    body = [P(-L / 2, -W / 2), P(L / 4, -W / 2), P(L / 2, 0), P(L / 4, W / 2), P(-L / 2, W / 2)]
    d.polygon(body, fill=col, outline=INK)
    d.line([P(-L / 2 + 8, -W / 2), P(-L / 2 + 8, W / 2)], fill=INK, width=3)


def skill_icon(kind, size=150):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size / 2
    if kind == "split":
        ix, iy = c + 2, c
        draw_bullet(d, ix - 38, iy, 0.0, L=50, W=22)
        d.regular_polygon((ix, iy, 13), 6, fill=(255, 245, 200), outline=INK)
        for a in (-0.62, 0.0, 0.62):
            draw_bullet(d, ix + 40 * math.cos(a), iy + 40 * math.sin(a), a, L=34, W=14, col=ORANGE)
    elif kind == "rate":
        ic = icon("fastForward.png", int(size * 0.72))
        im.alpha_composite(ic, ((size - ic.width) // 2, (size - ic.height) // 2))
    elif kind == "reinf":
        ic = icon("multiplayer.png", int(size * 0.74))
        im.alpha_composite(ic, ((size - ic.width) // 2, (size - ic.height) // 2))
    return im


# ---------------------------------------------------------------- one skill card
def card(img, x, y, w, h, spec):
    d = ImageDraw.Draw(img)
    core = spec["core"]
    theme = {"core": "Yellow", "stat": "Blue", "reinf": "Green"}[spec["type"]]
    if core:  # glow behind core cards
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rounded_rectangle((x - 16, y - 16, x + w + 16, y + h + 16), radius=48, fill=(255, 209, 102, 200))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(14)))
    frame = nine(sprite(f"{theme}/Default/button_square_depth_gradient.png"), w, h, b=12, s=4)
    img.alpha_composite(frame, (x, y))
    if core:  # second inner gold border = distinct frame for core cards
        d.rounded_rectangle((x + 10, y + 10, x + w - 10, y + h - 26), radius=30, outline=(255, 245, 200), width=5)
    # ribbon
    rib = nine(sprite(("Red" if core else "Grey") + "/Default/button_rectangle_depth_flat.png"), 168, 56, b=10, s=2)
    img.alpha_composite(rib, (x + w // 2 - 84, y - 28))
    d = ImageDraw.Draw(img)
    text_c(d, x + w // 2, y - 22, "割草核心" if core else ("补人" if spec["type"] == "reinf" else "数值"), fk(34),
           fill=WHITE if core else INK, stroke=2 if core else 0, sfill=INK)
    # icon disc
    disc = sprite(("Red" if core else "Grey") + "/Default/button_round_depth_flat.png").resize((176, 176), Image.LANCZOS)
    img.alpha_composite(disc, (x + w // 2 - 88, y + 46))
    ic = skill_icon(spec["icon"])
    img.alpha_composite(ic, (x + w // 2 - ic.width // 2, y + 46 + 10))
    d = ImageDraw.Draw(img)
    text_c(d, x + w // 2, y + 236, spec["name"], fk(56), stroke=5)
    # level pips
    lv, mx = spec["lv"]
    if mx:
        pw = 34
        tot = mx * pw + (mx - 1) * 8
        px = x + w // 2 - tot // 2
        for k in range(mx):
            fill = GOLD if k < lv else (60, 60, 70)
            d.rounded_rectangle((px + k * (pw + 8), y + 316, px + k * (pw + 8) + pw, y + 334), radius=8, fill=fill, outline=INK, width=3)
        text_c(d, x + w // 2, y + 342, f"{lv}/{mx} 级", fk(32), stroke=3)
    else:
        text_c(d, x + w // 2, y + 326, "可重复选择", fk(32), stroke=3)
    # effect panel
    d.rounded_rectangle((x + 22, y + 392, x + w - 22, y + h - 40), radius=22, fill=CREAM, outline=INK, width=3)
    text_c(d, x + w // 2, y + 412, spec["eff"], fk(34), fill=INK)
    text_c(d, x + w // 2, y + 462, spec["sub"], fn(22, "Medium"), fill=(90, 86, 80))


def battle():
    img = Image.open(BG).convert("RGBA")
    # dim + pick-one-of-three (HUD drawn on top so the boss bar stays readable in the mockup)
    ov = Image.new("RGBA", img.size, (12, 14, 22, 150))
    img.alpha_composite(ov, (0, 0))
    # HUD: top boss bar (level 3)
    boss_bar(img, 30, 52, 1020, 0.64, "突变巨兽", "第 3 关 · 小 Boss", "1.7万 / 2.7万", [0.60])
    note(img, 650, 214, "阶段线 60%：第 3 关只有两阶段", (30 + 128 + int((1050 - 22 - 158) * 0.60), 150))
    # variant: chapter boss during phase change (shielded / greyed)
    boss_bar(img, 30, 270, 820, 0.60, "突变巨兽", "第 10 关", "7.4万 / 12.4万", [0.60, 0.25], shielded=True, scale=0.8)
    note(img, 470, 404, "变体：阶段转换咆哮，无敌 1.5 秒（灰 + 斜纹 + 锁）")
    note(img, 470, 450, "第 10 关章节 Boss 三阶段，阶段线 60% / 25%")
    d = ImageDraw.Draw(img)
    # level-up banner
    ban = nine(sprite("Yellow/Default/button_rectangle_depth_gradient.png"), 560, 120, b=12, s=3)
    img.alpha_composite(ban, (260, 560))
    text_c(d, 540, 574, "升级！三选一", fk(72), fill=WHITE, stroke=6)
    # exp bar under banner
    d.rounded_rectangle((200, 700, 880, 728), radius=14, fill=INK)
    d.rounded_rectangle((204, 704, 876, 724), radius=10, fill=CYAN)
    text_c(d, 540, 736, "第 4 次升级 · 经验 34/34", fn(24), fill=(230, 235, 240))
    cards = [
        dict(type="core", core=True, icon="split", name="分裂子弹", lv=(2, 3), eff="命中后分裂出 3 发", sub="各 50% 伤害，±30° 散开"),
        dict(type="stat", core=False, icon="rate", name="急速射击", lv=(3, 5), eff="射速 +15%", sub="当前累计 +30% → +45%"),
        dict(type="reinf", core=False, icon="reinf", name="紧急增援", lv=(0, 0), eff="立刻 +5 人", sub="小队 27 → 32 人"),
    ]
    cw, ch, gap = 332, 560, 18
    x0 = (1080 - 3 * cw - 2 * gap) // 2
    for i, c in enumerate(cards):
        card(img, x0 + i * (cw + gap), 830, cw, ch, c)
    d = ImageDraw.Draw(img)
    note(img, 40, 1420, "核心卡（分裂/穿透/连发）：金色外框+内描边+红色标签+光晕")
    note(img, 40, 1466, "数值卡：蓝框；补人卡：绿框；等级用格子+“2/3 级”")
    # bottom: refresh button (ad) - sample secondary button
    btn = nine(sprite("Blue/Default/button_rectangle_depth_gradient.png"), 360, 110, b=12, s=3)
    img.alpha_composite(btn, (360, 1560))
    ic = icon("movie.png", 64)
    img.alpha_composite(ic, (392, 1580))
    d = ImageDraw.Draw(img)
    d.text((470, 1578), "刷新卡牌", font=fk(50), fill=WHITE, stroke_width=4, stroke_fill=INK)
    note(img, 300, 1690, "（示意：看广告刷新，是否要做待策划确认）")
    out = os.path.join(OUTDIR, "ui_mockup.png")
    img.convert("RGB").save(out, optimize=True)
    return out


# ---------------------------------------------------------------- result screens
def star(img, cx, cy, size, on=True):
    s = sprite("Yellow/Default/star.png" if on else "Grey/Default/star_outline_depth.png")
    s = s.resize((size, int(size * s.height / s.width)), Image.LANCZOS)
    if not on:  # darken the grey outline star so it reads on the light panel
        r, g, b, a = s.split()
        s = Image.merge("RGBA", [ch.point(lambda v: int(v * 0.55)) for ch in (r, g, b)] + [a])
    img.alpha_composite(s, (int(cx - s.width / 2), int(cy - s.height / 2)))


def coin(d, cx, cy, r):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GOLD, outline=INK, width=4)
    d.ellipse((cx - r * 0.62, cy - r * 0.62, cx + r * 0.62, cy + r * 0.62), outline=(200, 140, 30), width=4)


def part_icon(img, cx, cy, size):
    ic = icon("wrench.png", size)
    bg = sprite("Blue/Default/button_round_depth_gradient.png").resize((int(size * 1.35), int(size * 1.35)), Image.LANCZOS)
    img.alpha_composite(bg, (int(cx - bg.width / 2), int(cy - bg.height / 2)))
    img.alpha_composite(ic, (int(cx - size / 2), int(cy - size / 2) - 2))


def badge(img, x, y, w, title, body):
    d = ImageDraw.Draw(img)
    b = nine(sprite("Red/Default/button_rectangle_depth_gradient.png"), w, 104, b=12, s=3)
    img.alpha_composite(b, (x, y))
    d.text((x + 22, y + 10), title, font=fk(40), fill=WHITE, stroke_width=3, stroke_fill=INK)
    d.text((x + 22, y + 60), body, font=fn(24), fill=(255, 235, 225))


def result():
    base = Image.open(BG).convert("RGBA").filter(ImageFilter.GaussianBlur(6))
    img = base.copy()
    img.alpha_composite(Image.new("RGBA", img.size, (12, 14, 22, 165)))
    d = ImageDraw.Draw(img)
    # main win panel
    px0, py0, px1, py1 = 70, 150, 1010, 1270
    pnl = nine(sprite("Grey/Default/button_square_depth_flat.png"), px1 - px0, py1 - py0, b=12, s=4)
    img.alpha_composite(pnl, (px0, py0))
    d = ImageDraw.Draw(img)
    ban = nine(sprite("Yellow/Default/button_rectangle_depth_gradient.png"), 620, 130, b=12, s=3)
    img.alpha_composite(ban, (230, 92))
    text_c(d, 540, 108, "第 3 关 通关！", fk(76), stroke=6)
    # stars
    for k, (cx, cy, sz) in enumerate(((330, 340, 170), (540, 300, 210), (750, 340, 170))):
        star(img, cx, cy, sz, True)
    d = ImageDraw.Draw(img)
    conds = ["★1 通关", "★2 剩余 ≥32 人", "★3 Boss 技能命中 ≤1 次"]
    for k, s_ in enumerate(conds):
        text_c(d, [300, 540, 790][k], 440, s_, fn(23), fill=(70, 70, 80))
    # rewards
    d.text((120, 500), "本关奖励", font=fk(46), fill=INK)
    # coin row
    d.rounded_rectangle((110, 560, 970, 690), radius=24, fill=(255, 255, 255), outline=(200, 200, 210), width=3)
    coin(d, 185, 625, 42)
    d.text((250, 568), "金币 ×246", font=fk(60), fill=INK)
    d.text((252, 640), "通关 140 × 三星 1.5 = 210  +  局内拾取 36", font=fn(24, "Medium"), fill=(90, 86, 80))
    # parts row
    d.rounded_rectangle((110, 708, 970, 838), radius=24, fill=(255, 255, 255), outline=(200, 200, 210), width=3)
    part_icon(img, 185, 773, 60)
    d = ImageDraw.Draw(img)
    d.text((250, 716), "武器零件 ×15", font=fk(60), fill=INK)
    d.text((252, 788), "Boss 关首次通关奖励（普通关首通 5 个）", font=fn(24, "Medium"), fill=(90, 86, 80))
    # first-clear tag on the parts row (the 15 parts above ARE the first-clear grant)
    tag = nine(sprite("Red/Default/button_rectangle_depth_gradient.png"), 170, 56, b=10, s=2)
    img.alpha_composite(tag, (780, 726))
    d = ImageDraw.Draw(img)
    text_c(d, 865, 730, "首次通关", fn(26), fill=WHITE)
    # first-3-star chest: a SEPARATE grant, shown apart from the normal rewards above.
    # chest = 2 x the level's base clear coins (140 x 2 = 280; no star multiplier, no picked-up coins) + 5 parts
    d.text((120, 852), "额外：首次三星宝箱（单独发放，不计入上方）", font=fn(24), fill=(150, 40, 40))
    card = nine(sprite("Red/Default/button_rectangle_depth_gradient.png"), 860, 120, b=12, s=3)
    img.alpha_composite(card, (110, 888))
    chest = sprite("Yellow/Default/button_square_depth_gradient.png").resize((92, 92), Image.LANCZOS)
    img.alpha_composite(chest, (128, 898))
    img.alpha_composite(icon("star.png", 60), (144, 910))
    d = ImageDraw.Draw(img)
    d.text((240, 896), "金币 ×280  +  武器零件 ×5", font=fk(44), fill=WHITE, stroke_width=3, stroke_fill=INK)
    d.text((242, 960), "= 基础通关金币 140 × 2（不乘星级、不含局内拾取）", font=fn(24), fill=(255, 235, 225))
    # buttons
    nb = nine(sprite("Yellow/Default/button_rectangle_depth_gradient.png"), 520, 150, b=12, s=4)
    img.alpha_composite(nb, (280, 1030))
    d = ImageDraw.Draw(img)
    text_c(d, 515, 1050, "下一关", fk(80), stroke=6)
    img.alpha_composite(icon("right.png", 76), (680, 1066))
    for bx, ic_ in ((118, "return.png"), (850, "home.png")):
        rb = sprite("Blue/Default/button_square_depth_gradient.png").resize((116, 116), Image.LANCZOS)
        img.alpha_composite(rb, (bx, 1044))
        img.alpha_composite(icon(ic_, 70), (bx + 23, 1062))
    d = ImageDraw.Draw(img)
    text_c(d, 176, 1164, "重玩", fn(22), fill=INK)
    text_c(d, 908, 1164, "首页", fn(22), fill=INK)
    note(img, 120, 1204, "三星结算 210 + 拾取；宝箱 280 + 零件 5 另发；重复通关只给金币")

    # failure variant (smaller)
    fx0, fy0, fx1, fy1 = 150, 1320, 930, 1830
    fp = nine(sprite("Grey/Default/button_square_depth_flat.png"), fx1 - fx0, fy1 - fy0, b=12, s=3)
    img.alpha_composite(fp, (fx0, fy0))
    d = ImageDraw.Draw(img)
    fb = nine(sprite("Grey/Default/button_rectangle_depth_flat.png"), 440, 96, b=12, s=3)
    img.alpha_composite(fb, (320, 1286))
    d = ImageDraw.Draw(img)
    text_c(d, 540, 1296, "挑战失败", fk(58), fill=(90, 90, 100))
    for k, cx in enumerate((420, 540, 660)):
        star(img, cx, 1450, 96, False)
    d = ImageDraw.Draw(img)
    text_c(d, 540, 1510, "进度 100%（已进入 Boss 战）", fn(26), fill=(70, 70, 80))
    d.rounded_rectangle((200, 1556, 880, 1656), radius=22, fill=(255, 255, 255), outline=(200, 200, 210), width=3)
    coin(d, 262, 1606, 34)
    d.text((316, 1566), "金币 ×42", font=fk(52), fill=INK)
    d.text((560, 1582), "= 140 × 30% × 100%", font=fn(24, "Medium"), fill=(90, 86, 80))
    text_c(d, 540, 1664, "失败只给部分金币，没有武器零件和首通奖励", fn(22, "Medium"), fill=(120, 80, 80))
    rb = nine(sprite("Yellow/Default/button_rectangle_depth_gradient.png"), 260, 100, b=12, s=3)
    img.alpha_composite(rb, (230, 1706))
    ub = nine(sprite("Green/Default/button_rectangle_depth_gradient.png"), 300, 100, b=12, s=3)
    img.alpha_composite(ub, (520, 1706))
    d = ImageDraw.Draw(img)
    text_c(d, 360, 1718, "重试", fk(54), stroke=5)
    text_c(d, 670, 1718, "升级攻击力", fk(46), stroke=5)
    note(img, 40, 1846, "小变体：失败结算（第 3 关 Boss 战中失败）")
    out = os.path.join(OUTDIR, "ui_mockup_result.png")
    img.convert("RGB").save(out, optimize=True)
    return out


if __name__ == "__main__":
    print(battle())
    print(result())
