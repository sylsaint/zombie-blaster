# App branding

All images are rendered from our own models in `assets/models/*.glb` (chr_soldier_c + wpn_gatling, enm_walker, the
squad/horde/elite/boss_mutant) with Blender 4.2 (Cycles, same lighting/look as `tools/art/render_v3.py`), then
composited with Pillow. No third-party images. Regenerate:

```
~/apps/blender-4.2.23-linux-x64/blender -b --factory-startup -P tools/art/render_branding.py -- icon splash
python3 tools/art/render_branding.py
```

| File | Size | Alpha | Use |
| --- | --- | --- | --- |
| `icon_fg.png` | 432×432 | RGBA, transparent bg | Android adaptive icon foreground. Every opaque pixel lies inside the central 264 px safe circle (r ≤ 132). |
| `icon_bg.png` | 432×432 | RGB, opaque | Android adaptive icon background (teal sunburst). |
| `icon_main.png` | 192×192 | RGB, opaque | Combined legacy / Godot launcher icon (own full-bleed layout, subject larger than the adaptive one). |
| `icon_ios_1024.png` | 1024×1024 | RGB, no alpha channel, square corners | iOS App Store / app icon. |
| `splash_1080x1920.png` | 1080×1920 | RGB, opaque | Portrait splash. The title and squad sit inside the central 900×1560 area (x 90–990, y 180–1740), so it survives cropping to other aspect ratios. The boss's crystals and the far end of the lane go above that area; they are only decoration. |

- Title text **"ZOMBIE BLASTER" is a placeholder** (the repo name). The Chinese title 僵尸爆破 is not confirmed yet.
  To change it, edit `TITLE` in `tools/art/render_branding.py` and run the compose step again.
- Title font: ZCOOL KuaiLe 站酷快乐体, SIL OFL 1.1 (`research/third_party/fonts/`). The font is only used to bake
  the PNGs; it is not shipped by this folder. See `assets/CREDITS.md`.
- Preview of every file at actual size, plus launcher masks and 48/72/96 px: `docs/art/samples/sample_branding.png`.
