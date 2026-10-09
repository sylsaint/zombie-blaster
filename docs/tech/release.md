# 发版

Godot 版本钉在 `tools/godot.version`（当前 4.7.2 stable）。流水线是 `.github/workflows/release.yml`。GUT 的 `.github/workflows/test.yml` 不负责出包，两边互不影响。

## 什么时候跑

| 触发 | 做什么 |
| --- | --- |
| 推送 `v*` 标签，例如 `v0.1.0` | Android 和 iOS 都出包，并挂到**同名** GitHub Release。这是唯一会创建 Release 的路径。另外上传 profile APK artifact，不挂到 Release |
| 改 `.github/workflows/release.yml`、`export_presets.cfg`、`tools/release/**`、`tools/smoke_exported_menu.sh`、`tools/emulator_menu_smoke.sh` 或 `docs/tech/release.md` 的 pull request | 打 Android release / debug APK，去掉 release 模板里的 baseline profile，无头启动导出的 pck 确认主菜单和第 1 关，再在 API 34 的 x86_64 模拟器里安装 **release** APK 并截主菜单和第 1 关。都只上传 artifact。不跑 iOS，不创建 Release |
| Actions 里手动 `workflow_dispatch` | Android、profile 和 iOS 都出包，只上传 artifact，**不**创建 Release。可选输入 `artifact_tag` 用来拼文件名；留空时用 `manual-<短 SHA>` |

推送到 `master`（或其它分支）**不会**跑这条流水线。没有 `push.branches`。

`GODOT_CACHE` 在 step 里写成 `$RUNNER_TEMP/godot-release-cache`。`runner` 上下文不能用在 job 级 `env` 上，step 里的 `path: ${{ runner.temp }}/...` 可以。`.github/workflows/test.yml` 的 `actionlint` job 会在每次 PR 上检查全部 workflow。

文件名：

- `zombie-blaster-<tag>-android-release.apk`（artifact `android-apks`，标签构建会挂到 Release）
- `zombie-blaster-<tag>-android-debug.apk`（同上）
- `zombie-blaster-<tag>-android-profile.apk`（artifact `android-profile-apk`，只上传，**不**进 Release）
- 有 iOS 签名 Secrets：`zombie-blaster-<tag>-ios.ipa`
- 没有 iOS 签名 Secrets：`zombie-blaster-<tag>-ios-xcode-unsigned.zip`

`<tag>` 在标签推送时就是标签本身（带 `v`）。

版本号只在**标签构建**的工作副本里改，提交在仓库里的预设保持 `version/name` `0.1.0`、`version/code` `1`，本地导出和 `workflow_dispatch` 都用这两个值。

标签必须是 `vMAJOR.MINOR.PATCH`，例如 `v0.2.1`。预发布后缀（`v0.2.1-rc1`）会让 job 失败。

| 字段 | 标签 `v0.2.1` 时 |
| --- | --- |
| Android `version/name`，iOS `short_version` | `0.2.1`（去掉开头的 `v`） |
| Android `version/code`，iOS `application/version`（build number） | `201` |

`versionCode` 用 **semver：`major * 10000 + minor * 100 + patch`**。更高的版本号得到更大的 code，才能覆盖安装。不用 `GITHUB_RUN_NUMBER`：同一次标签重跑不应该把 code 抬高，商店认的是版本本身。minor 和 patch 各自最大 99，否则会撞号（`v0.2.100` 和 `v0.3.0` 都会变成 300），这种标签直接失败。`v0.0.0` 的 code 是 0，也会失败。同一个标签再打一次，code 不变，不能当成一次升级。

## Android

Job 跑在 `ubuntu-24.04`：

1. 按 `tools/godot.version` 安装 Godot 编辑器，用 `--headless` 导出，并安装同一版本的 export templates。编辑器和模板缓存在 Actions cache 里。
2. 安装 Temurin JDK 17 和 Android SDK。`android-actions/setup-android` 只装 `platform-tools`：cmdline-tools 16 已经删掉旧的 `tools` 包，动作的默认值还会去装它，job 会在导出前失败。接下来的步骤再装 target SDK 36 对应的 `build-tools`；36 装不上时退回 35。
3. `--export-release` 打 release 模板的 APK。真机性能只认这个包。再 `--export-debug` 打一个 debug 模板的包，用来排查。这两个包共用预设 `Android`，启动器名字是 **高速打僵尸**。预设 `Android Profile` 也用 `--export-release`（不用 debug 模板），包名 `com.zombieblaster.game.profile`，启动器名字是 **高速打僵尸 Profile**（和正式包在手机上能分开），feature tag `profile`。装上就进压测场景。步骤在 [../qa/device-test.md](../qa/device-test.md)。
4. 架构只有 **arm64-v8a**。要 32 位时再把预设里的 `architectures/armeabi-v7a` 改成 true。
5. `export_filter` 是 `all_resources`，所以 `data/levels/`（`level_01`–`level_03`）和 `assets/`（模型、贴图、vfx）会打进 APK。脚本在导出后检查这些路径还在；缺了就失败。`build/` 里放了 `.gdignore`，导出目录不会再被扫回去。
6. `gradle_build/use_gradle_build` 保持关闭，产物是 APK。上架 Play 的 AAB 以后再开 Gradle。
7. release 和 profile 两个包在签名前会删掉 `assets/dexopt/baseline.prof` 和 `baseline.profm`，再 `zipalign -P 16`（不能和 `-p` 一起用）并重新签名。debug 包保持 debug 模板原样。原因见下一节。
8. 导出之后 `tools/smoke_exported_menu.sh` 用同一套 Android 排除规则打一个 pck，无头启动，确认主菜单的「开始」可见，并且第 1 关在 4 秒游戏时间里画出士兵和行走僵尸。这个检查看的是包里的项目，不是手机上的 `libgodot_android.so`。
9. Android job 成功后，`emulator` job 在 GitHub 托管的 `ubuntu-24.04` 上用 udev 规则打开 KVM，再用 `reactivecircus/android-emulator-runner` 启动 API 34、`google_apis`、`x86_64` 的模拟器（Pixel 2，1080×1920）。它安装本轮导出的 **release** APK（arm64-v8a，靠系统镜像的 ARM 翻译运行），等 logcat 里的 `MENU_READY`，`adb exec-out screencap` 截主菜单，按 1080×1920 布局把「开始」(540, 1698) 和「第 1 关」(540, 376) 换算到模拟器分辨率后点击，等 15 秒再截一张。主菜单截图里按钮米色像素太少、画面几乎纯色，或应用 logcat 里有 `SCRIPT ERROR` / `FATAL`，job 失败。截图和 logcat 上传为 artifact `android-emulator-smoke`。

## 正式包只有 3D、没有菜单

v0.1.0 的 release APK 在小米 15 Pro（Android 16，Adreno 830）上只画出 3D 车道，主菜单和其它 2D/UI 不出现。同一套资源打出来的 debug 包，以及所有 debug 模板包，菜单都在。

两边的 `project.binary` 和资源文件一致。APK 之间对得上的差别只有两处：

- release 模板的 `libgodot_android.so`（debug 模板是另一份 so）
- release 模板多出来的 `assets/dexopt/baseline.prof` 和 `baseline.profm`

Godot 4.7 的 Android 模板用 Android Gradle Plugin 8.6 编出来，release 变体自带这份 baseline profile。非 Gradle 导出没有开关可以关掉它，预设里也没有对应项。ART 只给**不可调试**的安装应用这份 profile；debug 包是 debuggable，所以根本不会装上它。这和「只有 release 包丢菜单」一致。

处理是：`tools/release/export_android.sh` 在 `--export-release` 之后删掉这些 profile 条目和旧签名，按 16 KB 页对齐重新打包，再用同一次导出的 keystore 签名。正式包仍然用 release 模板的 so，不把 debug so 换进去。debug 包不改。

查过 Godot 4.7 的 issue，没有一条对得上「release 模板在 Adreno 上只画 3D、不画 2D，debug 模板正常」。能对上 Adreno 的报告是 Vulkan / Mobile 渲染器的花屏或几何丢失（例如 [#115217](https://github.com/godotengine/godot/issues/115217)、[#120299](https://github.com/godotengine/godot/issues/120299)）。本工程桌面和手机都是 Compatibility（`gl_compatibility`），shader baker 也关着。字体和 text server 在 pck 里，debug 和 release 是同一份，所以不是资源被裁掉。

如果去掉 profile 之后真机仍然只有 3D，剩下的差别就是 release 的 `libgodot_android.so`（优化和裁剪过的原生库）。那就要换自定义 release 模板，不是再改 pck。

签名：

- 预设里的 keystore 路径和密码都是空的，仓库里没有密钥。
- 默认用 `keytool` 生成的 debug keystore（别名 `androiddebugkey`，口令 `android`）签 **release 和 debug** 两个包，这样 release 包也能直接装到手机上。
- 三个 Secret **都有**时，release 包改用正式 keystore，debug 包仍然用 debug keystore：
  - `ANDROID_KEYSTORE_BASE64`：keystore 文件的 base64（不要换行）
  - `ANDROID_KEYSTORE_PASSWORD`：store 口令。Godot 要求 key 口令和 store 口令相同
  - `ANDROID_KEY_ALIAS`：key 别名
- 只配了其中一两个时，Android job 失败，避免把一个“以为已正式签名”的包发出去。

生成 base64（不要把 keystore 提交进 git）：

```bash
base64 -w0 release.keystore
```

macOS 没有 `-w0` 时用 `base64 < release.keystore | tr -d '\n'`。

本地打同一对 APK：

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME="$HOME/android-sdk"   # 里面要有 platform-tools 和 build-tools
export ARTIFACT_TAG=local
./tools/release/export_android.sh
```

脚本会把编辑器设置写到 `build/xdg/`（已忽略），从 `JAVA_HOME` / `ANDROID_HOME` 读 SDK，不会改你本机的 Godot 配置。

## iOS

Job 跑在 `macos-latest`（镜像自带 Xcode）。先用 release 模板导出 Xcode 工程（预设里 `application/export_project_only=true`，Godot 自己不会调用 `xcodebuild`）。

四个 Secret **都有**时才签名并导出 IPA：

| Secret | 内容 |
| --- | --- |
| `IOS_P12_BASE64` | 分发证书 `.p12` 的 base64 |
| `IOS_P12_PASSWORD` | 该 p12 的口令 |
| `IOS_PROVISION_PROFILE_BASE64` | `.mobileprovision` 的 base64 |
| `IOS_TEAM_ID` | Apple Team ID（10 位） |

脚本会把描述文件装进临时钥匙串和 `~/Library/MobileDevice/Provisioning Profiles/`，按描述文件判断导出方式（App Store / Development / Ad Hoc / Enterprise），再 `xcodebuild archive` 和 `-exportArchive`。这些值只写在 runner 的工作副本里，**不会**提交回 `export_presets.cfg`。

缺任何一个时：

- 日志和 job summary 写明 **iOS signing skipped**，并列出缺了哪些 Secret 的名字（不打印值）
- Godot 4.7 在 Team ID 为空时拒绝写出 Xcode 工程，所以工作副本里临时写成占位 `0000000000`。这不是真实团队，只为了让工程能生成
- 上传未签名的 Xcode 工程 zip，job 成功

有了 Apple Developer 账号之后，把上面四个 Secret 配齐即可，不用改流水线。

发布 job 用 `needs: [android, ios]`，条件是 `always() && needs.android.result == 'success'`，并且只在 `v*` 标签推送时跑。iOS 失败或没有产物时，Release 仍然挂上 APK；IPA / 未签名 zip 有才附上（`fail_on_unmatched_files: false`）。pull request 不跑 iOS，也不创建 Release。`workflow_dispatch` 会跑 iOS，但不创建 Release。profile APK 在单独的 artifact `android-profile-apk` 里，发布 job 不下载它。

包名和 bundle id 都是 `com.zombieblaster.game`（Profile 包是 `com.zombieblaster.game.profile`）。iOS 最低版本 15.0（Godot 4.7 模板的下限），设备家族是 iPhone。iOS 显示名和 Bundle display name（`INFOPLIST_KEY_CFBundleDisplayName`）取自 `project.godot` 的 `application/config/name`，是 **高速打僵尸**。Godot 4.7 的 iOS 预设没有单独的显示名字段，bundle id 不跟着显示名改。

## 不打进包里的东西

正式 Android 和 iOS 的 `exclude_filter` 是 `tests/*, addons/gut/*, scenes/debug/*`。主场景和 `scripts/` 里的玩法代码不引用 `res://tests/` 或 `res://scenes/debug/`。`Android Profile` 留下 `scenes/debug/stress_test.tscn`，仍然排除 `tests/*`、`addons/gut/*`、`docs/*`、`tools/*`。压力场景的无头跑法还是 `tools/smoke_stress.sh`。

`docs/` 和 `tools/` 各有一个 `.gdignore`。这两个目录没有 `.gd` / `.tscn` / `.tres`，里面的预览图和 shell 脚本不会被导入，也不会打进包。GUT 和 `tools/smoke_main.sh` 照常从仓库读测试和主场景。

## 品牌资源

图在 `assets/branding/`。换图时只改对应那一行，不要把密钥写进预设。iOS 的 `icons/icon_1024x1024` 如果指向一个不存在的文件，Godot 会让整个导出失败，所以 `tools/release/export_ios.sh` 只在文件缺失时清空工作副本里的这两行（提交回去的预设不变）。

| 文件 | 尺寸 | 用在 |
| --- | --- | --- |
| `assets/branding/icon_fg.png` | 432×432 | Android adaptive foreground |
| `assets/branding/icon_bg.png` | 432×432 | Android adaptive background |
| `assets/branding/icon_main.png` | 192×192 | Android `launcher_icons/main_192x192` |
| `assets/branding/icon_ios_1024.png` | 1024×1024，无 alpha | `icons/icon_1024x1024` 和 App Store 1024。其余 iOS 尺寸由 Godot 从这张缩放 |
| `assets/branding/splash_1080x1920.png` | 1080×1920 | 引擎内启动图（不是 Android 12 的系统 splash icon） |

`project.godot` 的 `boot_splash/image` 已经指向 `splash_1080x1920.png`，`fullsize` 打开。这张图的 `.import` 必须是 `compress/mode=0`（无损）。工程开了 ETC2/ASTC，Godot 初次导入可能会改成 VRAM 压缩，启动图就会不显示。单色 adaptive icon 还没做，预设里留空。Android 的 `splash_screen/icon` 也留空，这样系统启动页不会盖掉引擎内的启动图。

## 怎么打一个测试标签

```bash
git tag v0.1.0
git push origin v0.1.0
```

Release 页上会出现 release APK。没有 iOS Secret 时，iOS job 显示跳过签名，整次 Release 流水线仍然是绿的。删掉测试标签和对应 Release 即可，不要把调试签名的包当成上架包。
