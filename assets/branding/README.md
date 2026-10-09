# App branding

All images are rendered from our own models in `assets/models/*.glb` (chr_soldier_c + wpn_gatling, enm_walker, the
squad/horde/elite/boss_mutant) with Blender 4.2 (Cycles, same lighting/look as `tools/art/render_v3.py`), then
composited with Pillow. No third-party images. Regenerate:

```
~/apps/blender-4.2.23-linux-x64/blender -b --factory-startup -P tools/art/render_branding.py -- icon splash
python3 tools/art/render_branding.py                 # all compose steps: icons splash sample
python3 tools/art/render_branding.py splash sample   # title change only (icons have no text, leave them alone)
```

| File | Size | Alpha | Use |
| --- | --- | --- | --- |
| `icon_fg.png` | 432×432 | RGBA, transparent bg | Android adaptive icon foreground. Every opaque pixel lies inside the central 264 px safe circle (r ≤ 132). |
| `icon_bg.png` | 432×432 | RGB, opaque | Android adaptive icon background (teal sunburst). |
| `icon_main.png` | 192×192 | RGB, opaque | Combined legacy / Godot launcher icon (own full-bleed layout, subject larger than the adaptive one). |
| `icon_ios_1024.png` | 1024×1024 | RGB, no alpha channel, square corners | iOS App Store / app icon. |
| `splash_1080x1920.png` | 1080×1920 | RGB, opaque | Portrait splash. The title and squad sit inside the central 900×1560 area (x 90–990, y 180–1740), so it survives cropping to other aspect ratios. The boss's crystals and the far end of the lane go above that area; they are only decoration. |

- Game title: **高速打僵尸** (confirmed; replaces the placeholder "ZOMBIE BLASTER"). It appears only on the splash, as
  two stacked lines 高速 / 打僵尸 (200 px ZCOOL KuaiLe, dark #1A1A1F outline + drop shadow, yellow→orange fill), same
  position as the old two-word title (top y = 300, centred, inside the safe area). To change it, edit `TITLE` /
  `TITLE_LINES` in `tools/art/render_branding.py` and run `python3 tools/art/render_branding.py splash sample`.
- The icons (`icon_fg`, `icon_bg`, `icon_main`, `icon_ios_1024`) contain **no text**, so the rename did not change them.
- Title font: ZCOOL KuaiLe 站酷快乐体, SIL OFL 1.1 (`research/third_party/fonts/`). The font is only used to bake
  the PNGs; it is not shipped by this folder. See `assets/CREDITS.md`. 高速打僵尸 is covered by both the full font and
  the UI subset `assets/ui/fonts/ZCOOLKuaiLe-Regular.ttf` (all five chars are GB2312 level 1), so no re-subset was needed.
- Preview of every file at actual size, plus launcher masks and 48/72/96 px: `docs/art/samples/sample_branding.png`.
- Before/after of the rename (splash, title close-up, icons in circle/squircle/square masks at 192/96/48 px):
  `docs/art/samples/sample_branding_rename.png`, built by `python3 tools/art/compose_branding_rename.py` (the old
  splash is kept at `docs/art/samples/_raw/brand_splash_before_rename.png`).
