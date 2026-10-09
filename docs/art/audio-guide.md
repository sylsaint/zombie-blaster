# 音频指南

> 状态：v0.2，2026-10-09，已对齐 `docs/design/feel.md`。原则：厚重的低音给分量，短促清脆的高频给反馈。几百只怪同时被打时不能糊成噪音。

## 总线（Godot AudioBus）

`Master` → `Music`、`SFX`、`UI`。`SFX` 下面再分 `Weapons`、`Impacts`、`Enemies`。Boss 出场时 `Music` 侧链压缩，让警报声更突出。

## 防噪规则

- 同一音效的同时发声数有上限：枪声 4、命中 6、僵尸死亡 6、爆炸 3。超过就丢掉最旧的那个。
- 每次播放随机变调 ±5–8%，音量随机 ±2 dB，避免机关枪式的重复感。
- 小队人数越多，枪声越换成"齐射"层的循环素材，而不是叠加更多单发枪声。

## 连杀反馈

1.5 秒内持续击杀算连杀：每 10 连杀，击杀音效升高 1 个半音，最多升 12 个半音，断连后复位（`feel.md`）。连杀达到 20、50、100 时配一声短促的提示音。割草爽感主要靠这一条。

## 格式

- 音效：WAV 16-bit 44.1 kHz 单声道，导入后由 Godot 压缩。时长控制在 1 秒以内。
- 音乐：OGG Vorbis 立体声，约 128 kbps，可无缝循环。
- 路径：`assets/audio/sfx/`、`assets/audio/music/`。命名格式如 `sfx_rifle_shot_01.wav`、`mus_battle_loop.ogg`。

## 清单

| ID | 内容 | 阶段 |
| --- | --- | --- |
| `sfx_pistol_shot` / `sfx_rifle_shot` ×3 | 1、2 级武器单发（各 3 个变体） | M1 |
| `sfx_shotgun_shot` / `sfx_gatling_loop` / `sfx_rocket_launch` | 3–5 级武器 | M2 |
| `sfx_volley_loop` | 小队齐射循环（人多时替代单发） | M1 |
| `sfx_hit_flesh` ×3 | 命中僵尸，清脆短促 | M1 |
| `sfx_hit_metal` ×2 | 子弹打在铁甲上 | M2 |
| `sfx_zombie_die` ×3 | 僵尸倒地 / 碎裂（带连杀变调） | M1 |
| `sfx_combo_milestone` | 20 / 50 / 100 连杀提示 | M1 |
| `sfx_explosion_s` / `_m` / `_l` | 三档爆炸，低频要厚 | M1 |
| `sfx_gate_good` | 过增益门：上行和弦 | M1 |
| `sfx_gate_bad` | 过减益门：下行音 | M1 |
| `sfx_gate_tick` | 可射击门数值上涨 | M2 |
| `sfx_squad_loss` | 被扣人（配合手机震动 40 毫秒） | M1 |
| `sfx_level_up` / `sfx_card_pick` | 升级弹卡 / 选卡确认 | M1 |
| `sfx_elite_slam` | 精英砸地（含蓄力声） | M1 |
| `sfx_boss_warning` | Boss 来袭警报 1.5 秒 | M1 |
| `sfx_boss_roar` | 进场和阶段转换咆哮 | M1 |
| `sfx_boss_slam` / `sfx_boss_charge` / `sfx_boss_stun` | 砸地、冲锋、眩晕 | M1 |
| `sfx_boss_summon` / `sfx_acid_rain` | 召唤、酸液雨 | M2 |
| `sfx_acid_spit` / `sfx_acid_splash` | 吐酸僵尸 | M2 |
| `sfx_warning_tick` | 地面预警的滴答声（越来越快） | M1 |
| `sfx_coin` / `sfx_chest_open` | 金币、首次三星宝箱 | M1 |
| `sfx_ui_tap` | 按钮点击 | M1 |
| `sfx_win_fanfare` / `sfx_lose_sting` | 胜利 / 失败短乐句 | M1 |
| `mus_battle_loop` | 推进段 BGM，约 140 BPM，鼓点重，60–90 秒无缝循环 | M1 |
| `mus_boss_loop` | Boss 战 BGM，分三段变奏（阶段一 / 二 / 三，层层加打击乐），同调同速，可以在小节线上切换；狂暴时整体再加一层 | M1（先做一、二段） |
| `mus_menu_loop` | 主菜单 / 关卡选择 BGM，轻快 | M1 |

## 来源

优先用 CC0 素材库（例如 Kenney、OpenGameArt 上标注 CC0 的素材）加上 sfxr/jsfxr 生成的程序化音效。所有来源和许可证记录在 `assets/audio/CREDITS.md`。需要付费购买的素材，先问用户。
