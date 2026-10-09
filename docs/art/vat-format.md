# 顶点动画贴图（VAT）格式 zb-vat-1

> 状态：v1，2026-10-09。格式和技术负责人约定，样张只做了行走僵尸 `enm_walker` + `enm_walker_lod1`。
> 烘焙：`tools/art/bake_vat.py`；校验：`tools/art/verify_vat.py`、`tools/art/verify_glb.py`；预览：`tools/art/render_vat_preview.py` → `docs/art/samples/sample_walker_vat.png`。
> 本文件取代风格指南第 9 节旧的 VAT 写法（每个动作一张位置图加一张法线图，放在 `assets/textures/vat/`），旧写法作废。

## 1. 文件

每个动画模型对应三个文件：

| 文件 | 内容 |
| --- | --- |
| `assets/models/<名字>.glb` | 原模型，**原地**多写一套 `TEXCOORD_1`（Godot 里叫 UV2）。其他数据逐字节不变：位置、平面法线、调色板 UV0、索引、顶点顺序、单一材质 `mat_palette`，仍然没有 `COLOR_n` |
| `assets/models/anim/<名字>_vat.exr` | 动画贴图，OpenEXR，RGBA 半精度浮点（RGBA16F），ZIP 无损压缩 |
| `assets/models/anim/<名字>_vat.json` | 附带说明：贴图路径、宽高、fps、动作表、包围盒等 |

骨骼和动作的源文件保存在 `tools/art/vat_rigs/<名字>.blend`（目录里放了 `.gdignore`，Godot 不会导入）。

## 2. 贴图布局

- **X = 顶点列，Y = 帧行**。所有动作从上到下叠在同一张贴图里，宽 ≤ 2048。
- 第 0 行是文件里的第一条扫描线（图像最上面一行），对应 shader 里 `texelFetch(tex, ivec2(列, 行), 0)` 的 y = 0。
- 每个像素：**RGB = 该顶点相对静止姿势（也就是 glb 里的位置）的位移**，坐标系和 glb 相同（Y 朝上、朝向 -Z，单位米）；A 不用，固定为 1.0。
- 不烘焙法线。shader 用 `dFdx`/`dFdy` 求面法线（模型本来就是平面着色）。
- 一列对应一个“唯一顶点”：静止位置相同、并且挂在同一块骨头上的顶点共用一列（平面着色拆出来的重复顶点运动完全一样）。所以贴图宽度小于 glb 顶点数，比如行走者 776 个顶点只占 267 列。
- **不依赖顶点顺序**。每个顶点的列号写在 UV2 里：
  - `UV2.x = (列 + 0.5) / 宽`，所以 `列 = floor(UV2.x * 宽)`；
  - `UV2.y = 块 + 0.5`，所以 `块 = floor(UV2.y)`。只要列数 ≤ 2048，就只有一块，UV2.y 恒为 0.5（行走者就是这样）。
  - 列数超过 2048 时（以后的 Boss 可能会），按 2048 列折行，每帧占 `rows_per_frame` 行：`行 = start_row + 帧 * rows_per_frame + 块`。

## 3. json 字段

```json
{
  "format": "zb-vat-1",
  "model": "assets/models/enm_walker.glb",
  "texture": "assets/models/anim/enm_walker_vat.exr",
  "width": 267, "height": 48, "rows_per_frame": 1, "fps": 30,
  "clips": {
    "walk":  {"start_row": 0,  "frame_count": 24, "loop": true},
    "hit":   {"start_row": 24, "frame_count": 8,  "loop": false},
    "death": {"start_row": 32, "frame_count": 16, "loop": false}
  },
  "vertex_count": 776, "columns": 267,
  "aabb": {"min": [...], "max": [...]},
  "root_motion": false
}
```

`clips` 里每个动作还附带 `max_forward_reach_m`（向 -Z 最远伸出多少米）、`min_height_m`（最低点高度）、`ground`（落地方式）和 `action`（.blend 里的动作名）。`aabb` 是静止姿势和所有帧的并集，导入后填到 `custom_aabb` 里（再留一点余量），否则死亡倒地时会被视锥剔除。

**LOD 规则**：LOD1 和 LOD0 用同一套骨骼、同一份动作数据，fps、动作顺序、`start_row` 和 `frame_count` 完全一致（verify_vat 会检查），所以切 LOD 时动作不会跳。贴图宽度不同（每个 LOD 各自的列数），这没关系，列号从各自的 UV2 读。

## 4. 行走者动作（样张）

| 动作 | 行 | 帧数 | 时长 | 循环 | 内容 |
| --- | --- | --- | --- | --- | --- |
| walk | 0–23 | 24 | 0.8 s | 是 | 蹒跚走：左腿迈步，右腿拖着走（步子小、脚尖外撇），胯部左右晃，肩膀反向扭，头晚半拍晃动，双臂前伸上下颠。原地走，没有根运动 |
| hit | 24–31 | 8 | 0.27 s | 否 | 往后一缩：第 0 帧就被推开，第 1–2 帧最大（上身后仰 16°、头后仰 24°、双手上甩），第 5 帧稍微前冲，最后一帧回到静止姿势 |
| death | 32–47 | 16 | 0.53 s | 否 | 往后踉跄（0–4），以脚跟为支点向后倒（4–11，越倒越快），落地小弹一下（12），仰躺着两腿翘起、双手直直指向天（13–15）。最后一帧停住，再接溶解 |

- 前伸限制 0.6 米：walk 最大 0.576 米，hit 最大 0.566 米（LOD1 是 0.545 / 0.536）。death 是往后倒的，不受这个限制。
- 落地方式 `plant`：每一帧都把最低点放到地面 y = 0（腿是刚体，没有脚踝，胯部的起伏由腿的几何自然算出）。高度修正以 LOD0 为准，LOD1 直接沿用，这样两个 LOD 的骨骼变换完全相同。代价是 LOD1 的鞋底是斜的（脚尖翘起 4.7 厘米），走路时 LOD1 最多会离地 2.3 厘米，远景下看不出来。
- 移动速度建议：播放速度 1.0 时步幅大约对应 0.4 米/秒；游戏里移动更快时按比例加快播放。

## 5. Godot 端（Compatibility / GLES3）

**EXR 导入**：`compress/mode = Lossless`，`mipmaps/generate = false`，`process/hdr_clamp_exposure = false`，`detect_3d/compress_to = Disabled`。导入后确认格式是 `Image.FORMAT_RGBAH`（不能被转成 VRAM 压缩或 8 位）。

**glb 导入**：`meshes/light_baking` 不能选 Static Lightmaps（会重新生成 UV2，把列号覆盖掉）；`meshes/generate_lods = false`（LOD1 是手做的）；建议 `meshes/force_disable_compression = true`（压缩后 UV2 是 16 位定点数，精度其实也够，关掉压缩只是保险）。导入时引擎可能会合并顶点或重新排序，这不影响结果，因为列号写在 UV2 里。

**shader 示意**（按实例存起始行和帧号，具体做法由程序决定）：

```glsl
shader_type spatial;
uniform sampler2D palette : source_color, filter_nearest;
uniform sampler2D vat : filter_nearest, repeat_disable;
uniform int vat_rows_per_frame = 1;

void vertex() {
    // INSTANCE_CUSTOM.x = 动作的 start_row，INSTANCE_CUSTOM.y = 当前帧（0..frame_count-1）
    int col = int(UV2.x * float(textureSize(vat, 0).x));
    int row = int(INSTANCE_CUSTOM.x) + int(INSTANCE_CUSTOM.y) * vat_rows_per_frame + int(UV2.y);
    VERTEX += texelFetch(vat, ivec2(col, row), 0).rgb;
}

void fragment() {
    NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));  // 平面法线（观察空间）；如果明暗反了就交换两个参数
    ALBEDO = texture(palette, UV).rgb;
}
```

- 帧间插值可选：取 `frame` 和 `frame + 1`（循环动作取模，非循环动作停在最后一帧）两次 `texelFetch`，再 `mix`。
- 切换动作时姿势会跳：walk 的任意一帧都不等于 hit 的第 0 帧。要平滑的话，用两套行号做 2–3 帧交叉淡化；不做也可以接受，因为受击本来就是一个突然的动作。
- 凡是画这个网格的 pass（描边外壳等）都要加同样的 VAT 位移。注意：引擎导入时写进顶点色的平滑描边法线是**静止姿势**的方向，部件转得厉害时（比如 death 仰躺 90°）挤出方向会偏，需要程序评估一下描边效果。
- 精度：半精度浮点在 1–2 米之间的步长约 1 毫米。death 最大位移约 2.2 米，重建误差 < 1 毫米。

## 6. 烘焙流程（`tools/art/bake_vat.py`）

```
blender -b --factory-startup --python-exit-code 1 -P tools/art/bake_vat.py -- enm_walker enm_walker_lod1
blender -b --factory-startup --python-exit-code 1 -P tools/art/verify_vat.py -- enm_walker enm_walker_lod1
python3 tools/art/verify_glb.py assets/models/*.glb
blender -b --factory-startup --python-exit-code 1 -P tools/art/render_vat_preview.py -- enm_walker
python3 tools/art/render_vat_preview.py enm_walker
```

1. 读 glb，把每个网格按“连通 + 位置重合”拆成岛（v3 模型由一块块独立的倒角方块和管子拼成）。
2. 每个岛整块挂到离岛中心最近的骨头胶囊上（刚体蒙皮，权重 1）。骨骼按模型配置在 `RIGS` 里（根、胯、躯干、头、左右臂、左右腿）。`mesh_bone` 可以把整个网格对象强制挂到某块骨头上，Boss 的 `weakpoint` 就挂在躯干上，跟着身体动。
3. 分配列号并写 UV2，原地改写 glb（再跑一次会覆盖原来的 UV2，结果相同）。**重新运行 `gen_characters_v3.py` 会生成不带 UV2 的 glb，之后必须重新烘焙**；`verify_glb.py` 发现有 json 但没有 UV2 时会报 FAIL，反过来没有 json 却带 UV2 也会报 FAIL。
4. 把改好的 glb 导入 Blender，搭骨骼，每个动作建一个 action，逐帧通过 depsgraph 求值，写出位移。
5. `verify_vat.py` 独立校验：用 numpy 读 glb，用 Blender 自带的读图器解码 EXR（并和 OpenImageIO 的结果对比），打开保存的 .blend 求值，再按三角形角点逐一比较“glb 位置 + 按 UV2 取出的位移”和 Blender 的结果。

**以后加模型**：在 `RIGS` 里加一项，写上枢轴和胶囊坐标（用 Blender 坐标：x 向右、y 向前、z 向上），选 `clipset`，设 `amp`（动作幅度）、`reach`（前伸限制）和 `ground_ref`（LOD 共用哪个模型的落地数据）。士兵、快跑者、精英还要配各自的动作集（士兵是跑和射击，不是僵尸走）。Boss 用 `clipset: "boss"`，多一个循环的 `stun` 动作（向前弯腰、头垂下、手臂下垂、慢慢晃）；配置里加 `"mesh_bone": {"weakpoint": "torso"}`。两个网格对象共用一张贴图，列号在两个网格之间连续编号，所以 UV2 也写在两个网格上。
