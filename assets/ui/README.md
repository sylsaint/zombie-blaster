# assets/ui — shared UI theme (zombie-blaster)

Godot 4.7, Compatibility renderer, portrait 1080×1920. One `Theme` resource skins every UI scene:
Kenney UI Pack nine-patch buttons/panels recoloured to our palette (teal / yellow-orange / cream),
ZCOOL KuaiLe 站酷快乐体 as the main font with Noto Sans SC as glyph fallback.

```
assets/ui/
  theme/zb_theme.tres        Theme (text resource, 18.9 KB)
  textures/*.png             15 nine-patch textures (Kenney UI Pack, recoloured), ~19 KB total; SOURCES.txt
  icons/*.png                7 icons 128 px (coin, part, gear, attack, lock, star filled/empty), ~80 KB total
  fonts/ZCOOLKuaiLe-Regular.ttf   subset, 740 KB (original 1.5 MB)    + OFL.txt
  fonts/NotoSansSC-Medium.otf     subset, 791 KB (original 8.3 MB)    + NotoSansSC-OFL.txt
  fonts/charset.txt          3928 chars the fonts were subset to
  LICENSE-kenney-*.txt       Kenney CC0 licence texts
```
Whole folder ≈ 1.7 MB.

## Dropping it in (no scene changes)

PR #26 scenes (`main_menu`, `level_select`, `results_screen`, `meta_panel`) all reference
`res://assets/ui/game_theme.tres` and use the variations `Display` and `Body`. `zb_theme.tres` defines both, so either:

1. **Copy** `theme/zb_theme.tres` over `assets/ui/game_theme.tres` (all paths inside are absolute `res://assets/ui/...`, so the copy works as-is), or
2. point `GameTheme.PATH` and the four `ext_resource` lines at `res://assets/ui/theme/zb_theme.tres`.

What you get without touching scenes: every `Button` = yellow-orange primary, every disabled button = slate "locked" look,
`Display` = 96 px title, `Body` = 36 px body with outline + shadow, `PanelContainer` = dark translucent teal-bordered panel.

Note: `tests/test_rewards.gd::test_portrait_theme_font_slots_are_empty` asserts `theme.default_font == null`
(it guards the placeholder). With the real fonts that one assertion must be dropped/inverted; everything else in that test
still passes (Display/Body base type is Label, no font item on Display/Body, all Button/PanelContainer styleboxes exist,
no .ttf/.otf directly in `res://assets/ui/` — the fonts live in `fonts/`).

Set the project's default theme too if you want non-themed nodes covered: Project Settings → GUI → Theme → Custom = `res://assets/ui/theme/zb_theme.tres`.

## Theme type variations

Set `theme_type_variation` on the node (Inspector → Theme → Type Variation). All are property-only changes.

| Variation | Base | Look | Use on |
|---|---|---|---|
| *(default)* `Button` | — | yellow-orange Kenney depth button, 48 px dark text; disabled = slate | everything not listed below |
| `PrimaryButton` | Button | same as default (explicit) | 开始 `Play`, 下一关 `Next`, 重试 `Retry` on fail |
| `SecondaryButton` | Button | teal, white text, dark-teal outline | 返回 `Back`, 重试 `Retry` after a win, 首页 |
| `UpgradeButton` | Button | mint green, white text | 升级攻击力 `Upgrade` (meta panel); put `icons/icon_attack.png` in `icon` |
| `LockedButton` | Button | slate in every state, grey text | locked level rows (`Level2/3` while locked; set `icon = icon_lock.png`). Plain `disabled = true` gives the same look on any button |
| `SmallButton` | Button | 36 px text | square icon buttons (重玩 / 首页) |
| `Display` | Label | 96 px fire-yellow, 28 px ink outline, drop shadow | PR #26 alias of `TitleLabel` (keep for scenes as they are) |
| `TitleLabel` | Label | same as `Display` | screen titles 僵尸开炮 / 选择关卡 / 胜利 |
| `FailTitleLabel` | Label | 96 px pale grey, maroon outline | results title when lost (失败) |
| `HeaderLabel` | Label | 60 px cream, outline | chapter subtitle 第 1 章, section headers 本关奖励 |
| `StatLabel` | Label | 42 px white, outline | meta `Attack` / `Wallet`, results star rows `StarClear/StarSquad/StarHits` |
| `Body` | Label | 36 px cream, outline + shadow | PR #26 alias of `BodyLabel` |
| `BodyLabel` | Label | same as `Body` | general text over the 3D scene |
| `CaptionLabel` | Label | 28 px, **Noto Sans SC** (fallback ZCOOL) | small explanations, formulas, footnotes |
| `RewardLabel` | Label | 44 px ink, no outline | text inside `RewardPanel` (`ClearLine/RunLine/TotalLine/PartsLine`) |
| `RewardNoteLabel` | Label | 28 px Noto, slate | sub-line inside a reward card |
| `BannerLabel` | Label | 72 px dark brown | text on `BannerPanel` |
| *(default)* `Panel` / `PanelContainer` | — | dark translucent panel, teal border | `Breakdown` as authored (cream Body text stays readable) |
| `RewardPanel` | PanelContainer | cream Kenney card with lip | results `Breakdown`, chest card; **switch its labels to `RewardLabel`** (cream text on cream is unreadable) |
| `BannerPanel` | PanelContainer | yellow-orange plate | title plate like the mockup "第 3 关 通关!" |
| `ProgressBar` | — | dark track, yellow-orange fill, 28 px text | boss HP / progress if needed |

Recommended scene tweaks shown in row B of `docs/art/samples/sample_ui_theme.png`:
Title→`TitleLabel` (or `FailTitleLabel` when lost), Subtitle→`HeaderLabel`, meta labels & star rows→`StatLabel`,
Upgrade→`UpgradeButton`+attack icon, locked levels→`LockedButton`+lock icon, Back→`SecondaryButton`,
Breakdown→`RewardPanel` with its four labels→`RewardLabel`.

Font sizes (1080 px wide): title 96, banner 72, header 60, button 48, stat 42, body 36, caption 28.
Readability over 3D: every label over the scene has a `#1A1A1F` outline (10–28 px) and a 45 % black shadow offset 4–8 px.

Focus: the cyan focus ring (`btn_focus.png`) shows after keyboard/gamepad navigation; with Godot's default it also appears
after a tap. If that is unwanted on touch, set the buttons' `focus_mode = FOCUS_NONE` (or leave as is for accessibility).

## Fonts

- `default_font` = FontVariation (base `ZCOOLKuaiLe-Regular.ttf`, fallbacks `[NotoSansSC-Medium.otf]`). ZCOOL lacks
  ★ ☆ ≥ ≤ ← → ■ ● etc.; these come from Noto automatically (verified in Godot: `has_char('★') == true` through the fallback).
- `CaptionLabel` / `RewardNoteLabel` = FontVariation (base Noto Sans SC, fallback ZCOOL).
- Subset charset (`fonts/charset.txt`, 3928 chars): ASCII + GB2312 level-1 (3755 most common hanzi, covers the 3500
  常用字 list) + CJK punctuation/symbols + every non-ASCII char in string literals of the game repo
  (`scripts/ scenes/ data/`) + extra UI strings in `tools/art/ui/game_strings.txt`.
  Rebuild: `python3 tools/art/ui/build_fonts.py /path/to/zombie-blaster` (needs fontTools; Noto source:
  notofonts/noto-cjk `Sans/SubsetOTF/SC/NotoSansSC-Medium.otf`). **When new text with rare characters (GB2312 level-2,
  e.g. 渲 鬱) is added, add it to `game_strings.txt` and rebuild**, otherwise it renders as tofu.
- Godot import defaults are fine (dynamic rasterisation at each size). MSDF is not needed.

## Textures (Kenney UI Pack 2.0, CC0) — recolours, sources in `textures/SOURCES.txt`

| File | Kenney source (`PNG/…/Double/`) | Nine-patch margins L,T,R,B |
|---|---|---|
| `btn_primary_{normal,hover,pressed}` | Yellow `button_rectangle_depth_gradient` (hue −9° → yellow-orange) | 24,20,24,28 (pressed 24,28,24,20) |
| `btn_secondary_*` | Blue `button_rectangle_depth_gradient` → palette teal | same |
| `btn_upgrade_*` | Green `button_rectangle_depth_gradient` | same |
| `btn_locked` | Grey `button_rectangle_depth_flat` → slate | 24,20,24,28 |
| `btn_focus` | outline of Grey `button_rectangle_depth_flat`, cyan `#4CC9F0` | 24,20,24,28, centre not drawn |
| `panel_dark` | Grey `button_square_flat` → dark translucent, teal border | 24 all |
| `panel_reward` | Grey `button_rectangle_depth_flat` → cream | 24,20,24,28 |
| `bar_bg`, `bar_fill` | Grey / Yellow `Default/button_rectangle_flat` | 12 all |

Pressed textures are the depth button with the 8 px lip removed and the face pushed down 8 px; content margins move the label down with it.
Generators: `tools/art/ui/build_textures.py`, `build_icons.py`, `build_theme.py`.

## Icons (`icons/`, 128×128)

| File | Source |
|---|---|
| `icon_star_filled.png` | Kenney UI Pack `Yellow/Double/star.png` (unchanged, 128×120) |
| `icon_star_empty.png` | Kenney UI Pack `Grey/Double/star_outline_depth.png`, darkened + ink outline |
| `icon_part.png` (wrench), `icon_gear.png`, `icon_lock.png` | Kenney Game Icons `White/2x/wrench, gear, locked` on a round badge drawn by us |
| `icon_coin.png`, `icon_attack.png` (sword) | drawn by us (`build_icons.py`) in the same badge style |

## Validation

`tools/art/ui/godot_test/run.sh` builds a throw-away project with the PR #26 scenes (scripts stripped, nodes unchanged),
loads the theme in Godot 4.7.2 headless (checks variations/base types, every stylebox + texture, font fallback, scene load),
then renders the screens with `--rendering-driver opengl3` under xvfb. Output: `docs/art/samples/sample_ui_theme.png`,
`sample_ui_theme_states.png`, raw renders in `docs/art/samples/_raw/ui_theme_*.png`.

## Licences

- Kenney UI Pack 2.0 and Kenney Game Icons — CC0 1.0 (www.kenney.nl). Texts: `LICENSE-kenney-ui-pack.txt`, `LICENSE-kenney-game-icons.txt`.
- ZCOOL KuaiLe 站酷快乐体 — © 2018 The ZCOOL KuaiLe Project Authors, SIL OFL 1.1 (`fonts/OFL.txt`). No reserved font name.
- Noto Sans SC — © 2014-2021 Adobe, SIL OFL 1.1, Reserved Font Name "Source" (`fonts/NotoSansSC-OFL.txt`).
  Both fonts are subsets (glyph removal only, names unchanged); the OFL texts must ship alongside the fonts.
- Coin/sword icons, badges, recolours: original project work.
