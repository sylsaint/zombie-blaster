# 僵尸开炮（Zombie Blaster）

竖屏手机车道射击的工程骨架：左右拖动小队，穿过给兵或升级武器的门，迎面是尸潮、精英和 Boss。按关卡推进并发放奖励。

引擎是 **Godot 4.7.2 stable**（标准版，GDScript，不是 .NET）。渲染器用 Compatibility，面向低端 Android。当前仓库只有灰盒和基建：一条车道、后方偏上的相机、一个会跟着左右拖动的占位体。玩法系统还没做。设计文档会放进 `docs/design/`，在那之前不要按猜测去补规则。

## 环境

安装 [Godot 4.7.2 stable](https://godotengine.org/download/archive/4.7.2-stable/) 的 Linux / macOS / Windows 编辑器（不要装 .NET 构建）。版本号写在 `tools/godot.version`。GUT 9.7.1 已经放在 `addons/gut/`，对应 Godot 4.7。

## 打开

1. 启动 Godot，选择 **Import**，选中仓库根目录的 `project.godot`。
2. 主场景是 `scenes/main.tscn`，按 F5 运行。
3. 设计分辨率 1080×1920，竖屏。桌面窗口默认 540×960，可以拉高窗口，用来看更长的手机比例。拉伸模式是 `viewport` + `keep_width`：车道宽度保持 1080，更高的屏幕只是多看到一些纵深。

## 运行灰盒

占位体停在车道中间。鼠标左键按住左右拖（项目打开了 **Emulate Touch From Mouse**，会变成触摸拖动）。拖完整屏宽度相当于从一侧护栏到另一侧，到护栏就停。相机固定在车道中线后方偏上，不跟横向移动。地面上的圆片是假阴影，没有实时阴影。

## 测试

需要本机能运行 `godot`，或者设置 `GODOT` 为可执行文件路径：

```bash
chmod +x tools/run_tests.sh tools/smoke_main.sh   # 克隆后如果没有执行权限
GODOT=/path/to/Godot ./tools/run_tests.sh
```

`tools/run_tests.sh` 会先 `godot --headless --import`，再用 `godot --headless` 跑 GUT。测试在 `tests/`，配置是根目录的 `.gutconfig.json`。示例测试检查车道拖动的位移和边界夹紧。

只启动主场景、并在日志出现 `ERROR:` / `WARNING:` 时失败：

```bash
GODOT=/path/to/Godot ./tools/smoke_main.sh
```

编辑器里也可以用 **Project → Tools → GUT** 跑同一批测试。

GitHub Actions（`.github/workflows/test.yml`）在 push 和 pull request 上安装同一版 Godot，导入工程、跑主场景冒烟、再跑 GUT。

## 导出 Android

1. 用编辑器下载与 4.7.2 匹配的 **Export Templates**（Editor → Manage Export Templates）。
2. 导出预设 **Android** 已经写在 `export_presets.cfg`：
   - arm64-v8a APK（`gradle_build` 关闭）
   - 包名 `com.zombieblaster.game`，版本名 `0.1.0`，version code `1`
   - 沉浸式竖屏。朝向来自项目设置，不在预设里再写一遍
   - 未填写任何 keystore 路径或密码
   - 图标指向 `assets/branding/`（adaptive 前景/背景 432×432、主图标 192×192，iOS 1024）。启动图是 `project.godot` 里的 `boot_splash/image`（`splash_1080x1920.png`）
3. **Project → Export → Android** 导出调试 APK。调试签名用 Godot 自带的 debug keystore，不必把密钥放进仓库。
4. 正式签名不要写进 `export_presets.cfg`。密码放在 `.godot/export_credentials.cfg`（已被 `.gitignore` 忽略），或导出时设置环境变量：
   - `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
   - `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
   - `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`
   - 调试包对应 `GODOT_ANDROID_KEYSTORE_DEBUG_PATH` / `_USER` / `_PASSWORD`
5. 上架 Google Play 的 AAB 需要之后打开 **Use Gradle Build**。这会在 `android/` 生成 Gradle 工程，该目录已忽略。需要 32 位包时再勾 `armeabi-v7a`。

## 发版

推送 `v*` 标签会跑 `.github/workflows/release.yml`：打 arm64 的 release / debug APK，并在有苹果签名 Secrets 时打 IPA，挂到 GitHub Release。同一条流水线还会打 release 模板的 profile APK（包名 `com.zombieblaster.game.profile`），只上传 artifact，不进 Release。普通推送到 `master` 不会触发这条流水线。改这个 workflow 或 `export_presets.cfg` 的 pull request 只上传 Android APK artifact，不发 Release。手动 `workflow_dispatch` 同样只上传 artifact。没有 iOS Secrets 时 iOS job 跳过签名并上传未签名的 Xcode 工程，流水线保持绿色。步骤和 Secrets 在 [docs/tech/release.md](docs/tech/release.md)，真机压测在 [docs/qa/device-test.md](docs/qa/device-test.md)。

## 目录

| 路径 | 内容 |
| --- | --- |
| `scenes/` | 场景。现在只有灰盒主场景 |
| `scripts/` | GDScript |
| `tests/` | GUT 测试 |
| `assets/branding/` | 图标和启动图（Android adaptive、iOS 1024、1080×1920 启动图） |
| `assets/models/` `textures/` `audio/` `vfx/` `ui/` | 美术与特效资源 |
| `addons/gut/` | GUT 9.7.1（MIT） |
| `docs/design/` `art/` `qa/` `tech/` | 设计、美术、测试、技术文档 |
| `tools/` | 无头测试脚本、发版导出脚本和 Godot 版本号 |

技术约束（尸潮怎么批量画、门怎么做碰撞、面数预算）在 `docs/tech/architecture.md`。
