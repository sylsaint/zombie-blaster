# 现成素材和 UI 调研

> 2026-10-09。目的：用户觉得我们自制角色“贴图粗糙”，调研能商用的现成低模素材和 UI，判断能不能替换或补充。只下载了不用登录的免费素材，没有购买任何东西。
> 面数都是用 Blender 4.2 实测的三角面（脚本 `tools/art/research/measure_tris.py`，结果 `research/tri_counts.json`），只算实际显示的部件，不含角色身上挂着的备用武器。没实测的写“未核实”。

## 1. 结论先说

1. **免费素材里没有一套能直接满足我们的面数预算**。最接近的是 Kenney 迷你系列（士兵 793、僵尸 1078、枪 486 面），超预算 1.8–4 倍；KayKit 和 Quaternius 的角色每个 4300–7800 面，超 10 倍以上，只适合参考或做 Boss。
2. **推荐：Kenney 迷你系列作为免费首选**（CC0、Q 版方块风、色块式 UV 和我们的调色板思路一致、自带“双手持枪射击”动作）。但要手工减面到 ≤450，不能一键 Decimate（见第 4 节测试），枪建议继续用我们自己的 `wpn_*`。
3. **如果愿意花钱**：Polygon Blacksmith 的 Toony Tiny Soldiers（Unity 资源商店，现价 10 美元）官方标注角色 330–850 面、武器 100–430 面、全部共用一张 1024² 贴图，是唯一一套现成就接近预算的 Q 版士兵；同作者的 Toony Tiny Zombies 也是 10 美元，但面数未核实。建议先让用户决定要不要买，买前要确认能导出 FBX。
4. **UI**：Kenney UI Pack + Kenney Game Icons（都是 CC0）做按钮、星星、图标；字体用站酷快乐体（OFL）做标题、按钮、卡名，小字用 Noto Sans SC（OFL）。样张见 `docs/art/research/ui_mockup.png` 和 `docs/art/research/ui_mockup_result.png`。

## 2. 来源一览

“风格”指和我们的 Q 版低模（蓝色小兵、绿色僵尸、奶油色和青色环境、橙色特效）对不对路。“卡通光”指技术负责人计划的卡通着色 + 边缘光（rim light），描边只给士兵、精英和 Boss。

| 来源 / 包 | 许可（已在官方页核实） | 和我们相关的内容 | 风格 | 实测三角面 | 骨骼 / 动画 | 贴图方式 | 价格 | 改到我们预算的工作量 | 卡通光 + 描边效果 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Kenney Mini Characters（kenney.nl/assets/mini-characters） | CC0（官网 + 包内 `License.txt`） | 12 个 Q 版人物，其中 male-c 是蓝帽警察，最像士兵 | 很接近：Q 版、方块带倒角 | 690–876（male-c 793） | 7 根骨骼，32 个动作，含 `holding-both-shoot`、`walk`、`sprint`、`die` | 每包一张 512² colormap，UV 落在色块上 | 免费 | 中：要手工减面到 ≤450 | 好：纯色块、轮廓方正，描边干净 |
| Kenney Graveyard Kit 5.0 | CC0（同上） | `character-zombie`、`character-skeleton`、吸血鬼、幽灵 | 很接近，和 Mini Characters 是同一风格 | 僵尸 1078，骷髅 658 | 没有蒙皮，是分块的节点动画（走、攻击、死亡等），烘 VAT 照样可以 | 512² colormap（和 Mini 那张不同） | 免费 | 中偏高：要减面，LOD ≤200 更难；只有一种僵尸，其他僵尸得自己改 | 好 |
| Kenney Blaster Kit 2.1 | CC0 | 18 把玩具枪，还有弹夹、瞄准镜、手雷 | 一般：玩具泡沫枪，紫灰配色，不像真枪 | 296–486（blaster-d 486） | 无 | 512² colormap | 免费 | 中：减到 ≤120 会掉细节 | 好 |
| Kenney Blocky Characters 2.0 | CC0 | 18 个方块人 | 不对路，太像“我的世界” | 72 | 节点动画 | 每个角色一张 1024² 贴图 | 免费 | 面数够低，但风格不合 | 一般 |
| Kenney Animated Characters Survivors | CC0 | 1 个通用人体 + 换肤贴图（含 2 张僵尸皮） | 不对路：正常比例，不是 Q 版 | 1604（FBX） | 有骨骼，3 个动作（站、跳、跑） | 每个皮肤一张贴图 | 免费 | 高 | 一般 |
| KayKit Adventurers 1.0（GitHub KayKit-Game-Assets，itch kaylousberg） | CC0（包内 `LICENSE.txt` + itch 页面） | 骑士、游侠、法师、野蛮人；带十字弩，没有现代枪 | Q 版圆润，做工最好；但是奇幻题材 | 身体 4347–4777（游侠 4347），弩 792 | 41 根骨骼，76 个动作（含双手远程瞄准、射击） | 每个角色一张 1024² 渐变图集 | 免费（itch 随意付；付费档多 3 个角色） | 很高：要减 10 倍 | 一般：贴图自带渐变，和卡通明暗会叠两层，要把图集改平 |
| KayKit Skeletons 1.0 | CC0 | 4 个骷髅兵 | 同上；骷髅能凑合当僵尸 | 4588–5934（小兵 5288） | 41 根骨骼，95 个动作（含骷髅专用走路、复活） | 1024² 渐变图集 | 免费 | 很高 | 一般 |
| KayKit Mystery Monthly 第 4–6 季 | CC0（itch 页面） | 每季 14–15 个角色，是否有士兵 / 僵尸未核实 | 同 Adventurers | 未核实（说明里写和 Adventurers 技术规格相同） | 同上 | 同上 | 每季 19.99 美元 | 很高 | 一般 |
| Quaternius Toon Shooter Game Kit（quaternius.com/packs/toonshootergamekit.html） | 包页面标 CC0（见第 6 节注意事项） | 士兵、防化兵、敌人；15 把枪；场景道具 | 卡通但比例偏正常，头不够大 | 士兵身体 5828；AK 1122，手枪 990，冲锋枪 1006，霰弹枪 1264 | 43 根骨骼，14–17 个动作（含跑动开枪、站立开枪） | 不用贴图，每个角色 15–17 个纯色材质 | 免费 | 很高；还要把多材质合成一张图 | 好：纯色材质最适合卡通光，问题只在面数 |
| Quaternius Zombie Apocalypse Kit（quaternius.com/packs/zombieapocalypsekit.html） | 包页面标 CC0 | 4 个幸存者、4 种僵尸、2 只狗、枪、车 | 卡通写实，僵尸偏恐怖 | 幸存者 6210–8846，僵尸 3550–7822（Zombie_A 7822），步枪 2103 | 43–50 根骨骼，20–32 个动作（含爬行、跑动攻击） | 共用一张 512² 图集 | 免费 | 很高 | 一般 |
| Quaternius 其他：Ultimate Animated Character Pack、Ultimate Guns Pack、Animated Zombie Pack | 包页面标 CC0 | 50+ 人物、40 把枪、1 个图集僵尸 | 低模写实 | 未核实（官方 Google Drive 当天超额，没下载成） | 有动作 | 多为纯色材质 / 图集 | 免费 | 未评估 | 未评估 |
| Poly Pizza（poly.pizza） | 每个模型单独标，CC0 或 CC-BY 3.0 | 汇集了 Quaternius、Kenney 等人的单个模型，可直接下 GLB | 各不相同 | 见上 | 见上 | 见上 | 免费 | — | — |
| **付费对比** Synty POLYGON Apocalypse（syntystore.com） | Synty 一次性购买许可：不限引擎（明确写了 not limited by game engine），商店页写支持 Godot 4.6.2+；每份许可 5 个座位；禁止 NFT / 元宇宙、禁止拿去训练生成式 AI、源文件不得外传 | 30 个角色（含男女士兵、4 个僵尸）、86 把枪 + 模块化枪械、载具、建筑 | 不对路：写实比例的低模，不是 Q 版 | 未核实（官方不标面数） | 角色带骨骼，**不含动画** | Synty 惯用的共享图集（未核实） | 349.99 美元（Unity 商店打折时 174.99） | 很高，而且风格要整体换 | 一般 |
| **付费对比** Polygon Blacksmith Toony Tiny Soldiers（Unity 资源商店 177336） | Unity 资源商店标准 EULA，单实体；Unity 官方帮助文档说资源商店素材可以用在其他引擎，前提是遵守 EULA（嵌入成品里，不单独再分发） | 6 种身体、17 种头、14 种迷彩、88 种武器 | 很接近：Q 版卡通士兵 | 官方标注角色 330–850，武器 100–430（未实测） | 80+ 个动作（Unity Mecanim 人形） | 角色和武器共用一张 1024² 贴图 | 10 美元（原价 15） | 低：部分型号直接达标 | 好（未实测） |
| **付费对比** Polygon Blacksmith Toony Tiny Zombies（Unity 资源商店 100508） | 同上 | 男女僵尸身体和头各十几种，6 种武器 | 很接近 | 未核实 | 31 个动作 | 共用一张 512² 贴图，8 种配色 | 10 美元 | 未核实 | 未核实 |

已下载的素材都在 `research/third_party/` 下（每个包保留了许可文件）：

- `research/third_party/kenney/`：mini-characters、graveyard-kit、blaster-kit、blocky-characters、animated-characters-survivors、ui-pack、game-icons
- `research/third_party/kaykit/`：Adventurers、Skeletons（GitHub 直接下载）
- `research/third_party/quaternius/`：Toon Shooter 和 Zombie Apocalypse 的部分模型（官方 Google Drive 当天报“下载超额”，改从 Poly Pizza 镜像逐个下载，来源见 `SOURCES.txt`，许可说明见 `LICENSE_NOTE.txt`）
- `research/third_party/fonts/`：站酷快乐体、得意黑、Noto Sans SC，各带 OFL 文本

## 3. 三套候选和我们的 v2 对比

对比图：`docs/art/research/asset_compare.png`（每列一套：上面是 3/4 近景的士兵和僵尸，中间是枪，下面是游戏镜头，7 个兵对 7 个怪）。各套都用自己的贴图，灯光和我们的样张一样。渲染脚本：`tools/art/research/render_compare.py`、`tools/art/research/compose_compare.py`。

### A. Kenney 迷你系列（推荐的免费方案）

Mini Characters 的警察 male-c 当士兵，Graveyard Kit 的僵尸，Blaster Kit 的 blaster-d。

- 优点：CC0，不用署名；Q 版方块风，三个包风格统一；UV 落在色块上，思路和我们的调色板一样，换成我们的配色可以写脚本自动完成；士兵自带双手持枪射击、走、跑、死亡动作；骨骼只有 7 根，烘 VAT 很简单；方正轮廓在卡通光和描边下很清楚。
- 缺点：面数超 1.8–4 倍；一键 Decimate 会把脸和色块 UV 弄坏（见 `docs/art/research/kenney_decimate_test.png`），得手工减面；只有一种僵尸，快跑者、胖子、吐酸、铁甲、精英、Boss 都得我们自己改或者做；枪是玩具泡沫枪，跟“向僵尸开炮”的真枪感不同；三个包的 colormap 是三张不同的图，要合并或者重映射。

### B. KayKit 冒险者 + 骷髅

游侠 Rogue（带十字弩）当士兵，骷髅小兵当僵尸。

- 优点：CC0；做工最精致，Q 版圆润，和我们 v2 的“圆润”方向最像；动作最多（76–95 个）。
- 缺点：每个角色 4300–5300 面，超 10 倍，减到 450 等于重做；没有现代枪也没有僵尸；每个角色一张 1024² 渐变图集，渐变贴图和卡通明暗会打架。只建议拿来参考造型，或者以后改成 Boss（Boss 预算 ≤5000）。

### C. Quaternius 卡通射击 + 僵尸末日

Toon Shooter 的士兵和 AK，Zombie Apocalypse 的僵尸。

- 优点：题材最对（士兵、僵尸、真枪都有）；士兵是纯色材质，最适合卡通光；动作里有跑动射击。
- 缺点：士兵 5828 面、僵尸 7822 面、AK 1122 面，超 10 倍以上；士兵 15+ 个材质，要合图；比例偏正常，头不够大；僵尸偏恐怖，和“卡通搞笑”要求不符；许可页面最近改过（见第 6 节）。

### 能不能换成我们的配色

- Kenney：能，最容易。UV 都落在纯色块上，可以写脚本按颜色把每个面的 UV 挪到我们 `assets/textures/palette.png` 里最近的色块中心，缺的颜色（发色、僵尸橙眼睛）往调色板下面追加一行。
- KayKit：能，但要改渐变图集，或者把渐变压平后重映射，工作量中等。
- Quaternius：士兵是纯色材质，可以直接把材质颜色换掉再烘成调色板 UV；僵尸是 512² 图集，要改图。

## 4. 减面测试（Kenney）

`tools/art/research/decimate_test.py` 用 Blender Decimate（塌陷）把 Kenney 士兵减到 449 面、僵尸减到 446 和 198 面、枪减到 119 面，结果见 `docs/art/research/kenney_decimate_test.png`（上排原模，下排减面后）。

- 数量能达标，但士兵脸部和帽子的色块被拉花，僵尸 198 面版本手臂和腿裂开，200 面的 LOD 基本不能用。
- 枪减到 119 面还能看，但细节明显变少。
- 结论：要按部件手工减（删看不见的面、去掉小倒角、合并平面），估计士兵和僵尸各 0.5–1 天，LOD 另算。

## 5. 推荐

1. **免费路线**：用 Kenney 迷你系列做士兵和普通僵尸的底模，手工减到 ≤450（LOD ≤200），UV 重映射到我们的调色板；枪继续用我们自己的 `wpn_*`（已经 ≤120 面、在调色板上）；精英和 Boss 继续自己做，参考 KayKit 的圆润造型。总面数估算（40 兵 + 100 个高模僵尸 + 200 个 LOD 僵尸）：40 × (450 + 120) + 100 × 450 + 200 × 200 ≈ 10.8 万，在 15 万以内。如果不减面直接用：40 × (793 + 486) + 100 × 1078 + 200 × 1078 ≈ 37.5 万，超标很多。
2. **付费路线（要用户点头）**：先买 Toony Tiny Soldiers（10 美元）看看实际面数和贴图，满意再买 Toony Tiny Zombies（10 美元）。注意这两个包是 Unity 包，要先在 Unity 里导出 FBX 才能进 Blender 和 Godot。
3. **不推荐**：KayKit 和 Quaternius 当主力（面数超 10 倍），Synty POLYGON Apocalypse（贵、写实比例、不含动画）。
4. 另外，“贴图粗糙”的观感有一部分来自目前的平面光照。技术负责人计划的卡通着色 + 边缘光 + 描边对我们的 v2 同样有效，建议换素材之前先用新 shader 重渲一次 v2 做对比。

## 6. 许可注意事项

- **Kenney、KayKit**：CC0，包内有许可文件，官网页面一致。CC0 不需要署名。
- **Quaternius**：各个包页面都标 CC0，但官网的许可页（quaternius.com/license.html）现在是“Quaternius Asset License (QAL) v1.0”，2026-08-28 更新：可以免费商用、不用署名，但不能把素材本身转售或再分发；第 7 条写明修改不追溯已经拿到的素材。Poly Pizza 镜像上有个别 Quaternius 僵尸标的是 CC-BY 3.0（比如 `research/third_party/quaternius/zombie_apocalypse_kit_polypizza/Zombie_C.glb`），和官网不一致。**如果要用，上线前从官方下载页重新下载，按 zip 里自带的许可文件为准。**
- **Synty**：一次性购买许可不限引擎，每份 5 个座位，禁止用于 NFT、元宇宙、生成式 AI 训练，源文件不能给团队外的人。
- **Unity 资源商店**：标准 EULA 允许嵌入游戏后在其他引擎使用（Unity 官方帮助文档的说法），不能单独再分发素材；单实体许可。
- 我们下载的第三方文件只用于评估，**不要放进游戏仓库或再分发**，正式采用时再按上面的规则整理。

## 7. UI 素材和字体

| 名称 | 许可（已核实） | 用途 | 说明 |
| --- | --- | --- | --- |
| Kenney UI Pack 2.0（kenney.nl/assets/ui-pack） | CC0 | 按钮、卡框、星星、进度条 | 5 种颜色（蓝、绿、灰、红、黄），430+ 张 PNG + 矢量源文件；按钮小图用九宫格拉伸成卡牌和面板 |
| Kenney Game Icons（kenney.nl/assets/game-icons） | CC0 | 图标：快进（射速）、多人（增援）、扳手（零件）、锁、警告、首页、重玩 | 黑白两版，1x / 2x |
| OpenGameArt Mobile Game GUI Buttons（SethByrd） | CC0（OpenGameArt 页面；作者说过包内许可文件已改成一致） | 备选按钮 | 只有 PSD，没下载 |
| Wenrexa Free UI KIT White #5（itch） | CC0（itch 页面） | 备选，偏简约 | 没下载 |
| 站酷快乐体 ZCOOL KuaiLe | SIL OFL 1.1（Google Fonts，包内 `ZCOOLKuaiLe-OFL.txt`） | 标题、按钮、卡名、数字 | 圆润可爱，适合休闲风；约 7000 字，覆盖常用字但不是全部 GBK，所有游戏文本要过一遍缺字检查 |
| Noto Sans SC | SIL OFL 1.1（保留名 “Source”） | 小字说明、缺字回退 | 字全；Godot 里设成快乐体的回退字体 |
| 得意黑 Smiley Sans | SIL OFL 1.1（保留名 “Smiley”“得意黑”） | 可选：伤害数字、结算大数字 | 斜体窄体，冲击感强；只有一种斜体 |
| 阿里妈妈方圆体 | **不是 OFL**，是阿里自己的免费商用协议（据第三方字体站转述：可商用、可嵌入 App，不能改字形、不能转售，不能用来注册商标）；未在官网逐条核实 | 不推荐 | 想用的话先去 fonts.alibabagroup.com 看原文 |

OFL 字体可以子集化后打进游戏；如果改字形后再发布，不能继续用保留字体名。

UI 样张（都是 1080×1920 竖屏，脚本 `tools/art/research/make_ui_mockup.py`，背景是我们 v2 模型的游戏镜头渲染，精英巨尸放大后临时代替还没做的 Boss）：

- `docs/art/research/ui_mockup.png`：Boss 血条（第 3 关突变巨兽 2.7 万血，60% 阶段线）；下方小一号的变体是第 10 关章节 Boss 在阶段转换时的样子（灰色 + 斜纹 + 锁，“无敌 1.5s”，60% 和 25% 两条阶段线）；中间是三选一卡牌，用 M1 的卡：分裂子弹 2/3 级（命中后分裂出 3 发）、急速射击 3/5 级（射速 +15%）、紧急增援（立刻 +5 人）。核心卡（分裂、穿透、连发）用金色外框 + 内描边 + 红色“割草核心”标签 + 光晕，数值卡用蓝框，补人卡用绿框。底部“刷新卡牌”按钮只是示意，要不要做待策划确认。
- `docs/art/research/ui_mockup_result.png`：第 3 关三星通关结算。金币 246 = 通关 140 × 三星 1.5 + 局内拾取 36（拾取数是示意值）；武器零件 15（Boss 关首通，零件行右侧挂红色“首次通关”标签）。“首次三星宝箱”是**单独发放**的一份奖励，放在本关奖励下面的独立红色卡片里，不计入上面的 246：金币 = 本关基础通关金币 × 2 = 140 × 2 = **280**（不乘星级、不含局内拾取），另加**武器零件 ×5**。（2026-10-09 按策划更正：之前写成“金币 ×2”，容易被理解成把本关结算翻倍。）“下一关”大按钮。下面是失败结算小变体：Boss 战中失败，进度算 100%，金币 42 = 140 × 30% × 100%，没有零件和首通奖励。
- 粉红色的小标签是给策划看的标注，不是游戏 UI。

## 8. 如果采用 Kenney 方案，要改的文档

`docs/art/style-guide.md`：

- 第 3 节调色板：保留“全项目一张调色板”的规则，Kenney 模型的 UV 重映射到 `assets/textures/palette.png`；需要追加一行人物色（几种发色、肤色深浅、僵尸橙眼睛），贴图从 256×128 加高到 256×256（指南本来就允许追加）。另一个办法是改用合并后的 512² Kenney colormap，那样第 3 节整节要重写，不推荐。
- 第 4 节造型：现在写着“用 6–8 边圆柱和球体，不用方块堆叠”，和 Kenney 的方块倒角风冲突，要改成“方块带倒角的 Q 版，约 2 头身”；士兵从约 2.2 头身改成约 2 头身。
- 第 4 节倒角和法线：Kenney 是硬边，描边如果用外扩壳（inverted hull）要另存一份平滑法线（存顶点色或 UV2），这一条对 v2 也一样适用，建议加进第 7 节或技术文档。
- 第 9 节资源规范：加一条“第三方来源记录”（来源、许可、原文件名、改动），放 `docs/art/third-party.md`。

`docs/art/asset-list.md`：

- `chr_soldier_a/b/c`：底模改为 Kenney male-c，b、c 档的头盔、背心、肩甲我们自己加，面数仍 ≤450。
- `enm_walker`：底模改为 Graveyard Kit 僵尸；`enm_runner`、`enm_brute`、`enm_spitter`、`enm_armored` 在它基础上改体型和配件；LOD1 手工做。
- `wpn_*`：保持我们现有的 5 把（不用 Blaster Kit）。
- `enm_elite_brute`、`boss_mutant`：继续自制，可以参考 KayKit 的造型。
- 动画：士兵用 Kenney 的 `holding-both-shoot`（射击）、`sprint`（跑）、`die`（倒地）烘 VAT；僵尸用 `walk`、`attack-melee-right`、`die`，帧数按清单重采样。
- 每个条目加“来源”一列（自制 / Kenney + 许可）。
