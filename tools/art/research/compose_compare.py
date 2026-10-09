"""Compose docs/art/research/asset_compare.png from the raw renders of render_compare.py.
Usage: python3 tools/art/research/compose_compare.py"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
RAW = os.path.join(ROOT, "docs/art/research/_raw")
FONTS = os.path.join(ROOT, "research/third_party/fonts")
OUT = os.path.join(ROOT, "docs/art/research/asset_compare.png")


def font(size, weight="Bold"):
    f = ImageFont.truetype(os.path.join(FONTS, "NotoSansSC-VF.ttf"), size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


BG = (244, 235, 217)
INK = (30, 30, 36)
SUB = (95, 92, 85)
OK, WARN, BAD = (6, 160, 120), (230, 140, 40), (205, 60, 55)

COLS = [
    dict(key="v2", title="当前 v2（自制基线）", src="chr_soldier_b · enm_walker · wpn_rifle",
         lic="自有", lic_c=(80, 80, 90), tris=("士兵 432", "僵尸 440", "枪 112"), budget=("预算内", OK),
         foot=["贴图：共用 palette 256×128", "换色：直接改色块", "卡通光+描边：平面色块，最稳"]),
    dict(key="kenney", title="Kenney 迷你系列", src="Mini Characters · Graveyard Kit · Blaster Kit",
         lic="CC0", lic_c=OK, tris=("士兵 793", "僵尸 1078", "枪 486"), budget=("超 1.8–4 倍，可减面", WARN),
         foot=["贴图：每包一张 colormap 512²（3 张不同）", "换色：容易（色块式 UV，改图即可）", "卡通光+描边：方块造型，轮廓清楚"]),
    dict(key="kaykit", title="KayKit 冒险者 + 骷髅", src="Adventurers · Skeletons（无枪，用弩代替）",
         lic="CC0", lic_c=OK, tris=("士兵 4347", "骷髅 5288", "弩 792"), budget=("超 10 倍以上", BAD),
         foot=["贴图：每角色 1024² 渐变图集", "换色：中等（要改渐变图集）", "卡通光：渐变贴图与卡通明暗会叠加"]),
    dict(key="quaternius", title="Quaternius 射击 + 末日", src="Toon Shooter Kit 士兵/AK · Zombie Apocalypse 僵尸",
         lic="CC0（官网）*", lic_c=OK, tris=("士兵 5828", "僵尸 7822", "枪 1122"), budget=("超 10 倍以上", BAD),
         foot=["贴图：士兵 15+ 个纯色材质；僵尸 512² 图集", "换色：士兵易（材质色），合图要返工", "卡通光：纯色材质适合，但面数太高"]),
]

W, CW = 1600, 400
TITLE_H, HEAD_H, CLOSE_H, GUN_H, GL_H, GAME_H, FOOT_H, NOTE_H = 78, 150, 380, 150, 30, 450, 108, 54
H = TITLE_H + HEAD_H + CLOSE_H + GUN_H + GL_H + GAME_H + FOOT_H + NOTE_H

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)
d.text((24, 16), "第三方素材对比：士兵 / 僵尸 / 枪（各用自带贴图，同一灯光，角色统一缩放到约 1.6 m）", font=font(28), fill=INK)
d.text((24, 52), "面数 = Blender 实测三角面（只算显示的部件，不含隐藏的备用武器）。预算：士兵、僵尸 ≤450，LOD ≤200，枪 ≤120。",
       font=font(16, "Regular"), fill=SUB)


def chip(x, y, text, col, f):
    tw = d.textlength(text, font=f)
    d.rounded_rectangle((x, y, x + tw + 16, y + f.size + 10), radius=8, fill=col)
    d.text((x + 8, y + 3), text, font=f, fill=(255, 255, 255))
    return x + tw + 24


for i, c in enumerate(COLS):
    x0 = i * CW
    y = TITLE_H
    if i:
        d.line((x0, TITLE_H, x0, H - NOTE_H), fill=(214, 202, 178), width=2)
    d.text((x0 + 14, y + 6), c["title"], font=font(24), fill=INK)
    d.text((x0 + 14, y + 40), c["src"], font=font(13, "Regular"), fill=SUB)
    nx = chip(x0 + 14, y + 66, c["lic"], c["lic_c"], font(15))
    chip(nx, y + 66, c["budget"][0], c["budget"][1], font(15))
    d.text((x0 + 14, y + 106), "  ·  ".join(c["tris"]) + " 三角面", font=font(17), fill=INK)
    y += HEAD_H
    close = Image.open(os.path.join(RAW, c["key"] + "_close.png")).convert("RGB").resize((CW - 4, CLOSE_H), Image.LANCZOS)
    img.paste(close, (x0 + 2, y))
    y += CLOSE_H
    gun = Image.open(os.path.join(RAW, c["key"] + "_gun.png")).convert("RGB").resize((CW - 4, GUN_H), Image.LANCZOS)
    img.paste(gun, (x0 + 2, y))
    y += GUN_H
    d.text((x0 + 14, y + 4), "游戏镜头（身后偏上，7 兵对 7 怪）", font=font(15), fill=SUB)
    y += GL_H
    game = Image.open(os.path.join(RAW, c["key"] + "_game.png")).convert("RGB").resize((CW - 4, GAME_H), Image.LANCZOS)
    img.paste(game, (x0 + 2, y))
    y += GAME_H
    for k, line in enumerate(c["foot"]):
        d.text((x0 + 14, y + 10 + k * 30), line, font=font(15, "Regular"), fill=INK)

d.text((24, H - NOTE_H + 8), "* Quaternius 官网各包页面标 CC0，但官网许可页已改为 QAL v1.0（可商用、不可转售素材），Poly Pizza 镜像把个别僵尸标为 CC-BY 3.0；上线前按官网 zip 内的许可文件核对。",
       font=font(14, "Regular"), fill=SUB)
d.text((24, H - NOTE_H + 30), "KayKit 免费包里没有现代枪械和僵尸，这里用弩和骷髅代替。Kenney 士兵用 Mini Characters 里的警察（male-c）+ Blaster Kit 的 blaster-d。",
       font=font(14, "Regular"), fill=SUB)
img.save(OUT, optimize=True)
print(OUT, img.size)
