# 发版

Godot 版本钉在 `tools/godot.version`（当前 4.7.2 stable）。流水线是 `.github/workflows/release.yml`。GUT 的 `.github/workflows/test.yml` 不负责出包，两边互不影响。

## 什么时候跑

| 触发 | 做什么 |
| --- | --- |
| 推送 `v*` 标签，例如 `v0.1.0` | Android 和 iOS 都出包，并挂到**同名** GitHub Release |
| Actions 里手动 `workflow_dispatch` | 只把包上传成 artifact，**不**创建 Release。可选输入 `artifact_tag` 用来拼文件名；留空时用 `manual-<短 SHA>` |

文件名：

- `zombie-blaster-<tag>-android-release.apk`
- `zombie-blaster-<tag>-android-debug.apk`
- 有 iOS 签名 Secrets：`zombie-blaster-<tag>-ios.ipa`
- 没有 iOS 签名 Secrets：`zombie-blaster-<tag>-ios-xcode-unsigned.zip`

`<tag>` 在标签推送时就是标签本身（带 `v`）。APK 里的 version name / version code 不跟标签走，用的是 `export_presets.cfg` 里的 `version/name` 和 `version/code`（现在是 `0.1.0` / `1`）。打标签之前如果要改版本，改这两处，再提交。

## Android

Job 跑在 `ubuntu-24.04`：

1. 按 `tools/godot.version` 安装 Godot 编辑器，用 `--headless` 导出，并安装同一版本的 export templates。编辑器和模板缓存在 Actions cache 里。
2. 安装 Temurin JDK 17 和 Android SDK（`platform-tools`，以及 target SDK 36 对应的 `build-tools`；36 装不上时退回 35）。
3. `--export-release` 打 release 模板的 APK。真机性能只认这个包。再 `--export-debug` 打一个 debug 模板的包，用来排查。
4. 架构只有 **arm64-v8a**。要 32 位时再把预设里的 `architectures/armeabi-v7a` 改成 true。
5. `export_filter` 是 `all_resources`，所以 `data/levels/`（`level_01`–`level_03`）和 `assets/`（模型、贴图、vfx）会打进 APK。脚本在导出后检查这些路径还在；缺了就失败。`build/` 里放了 `.gdignore`，导出目录不会再被扫回去。
6. `gradle_build/use_gradle_build` 保持关闭，产物是 APK。上架 Play 的 AAB 以后再开 Gradle。

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

包名和 bundle id 都是 `com.zombieblaster.game`。iOS 最低版本 15.0（Godot 4.7 模板的下限），设备家族是 iPhone。

## 品牌资源

`export_presets.cfg` 已经按下面的路径写好。换图时只改对应那一行，不要把密钥写进预设。文件还不在仓库里时，Android 导出退回工程图标 `icon.svg`。iOS 不一样：`icons/icon_1024x1024` 指向缺失文件会让整个导出失败，所以 `tools/release/export_ios.sh` 在工作副本里把这两行清空（提交回去的预设不变），job 仍然成功。

| 文件 | 尺寸 | 用在 |
| --- | --- | --- |
| `assets/branding/icon_fg.png` | 432×432 | Android adaptive foreground |
| `assets/branding/icon_bg.png` | 432×432 | Android adaptive background |
| `assets/branding/icon_main.png` | 192×192 | Android `launcher_icons/main_192x192` |
| `assets/branding/icon_ios_1024.png` | 1024×1024，无 alpha | `icons/icon_1024x1024` 和 App Store 1024。其余 iOS 尺寸由 Godot 从这张缩放 |
| `assets/branding/splash_1080x1920.png` | 1080×1920 | 引擎内启动图（不是 Android 12 的系统 splash icon） |

启动图先别写进 `project.godot`。`boot_splash/image` 指向一个不存在的文件时，无头启动会打出 `ERROR:`，`tools/smoke_main.sh` 会失败。图进仓库之后，在 `[application]` 里加上（导入必须是无损，不要 VRAM 压缩）：

```
boot_splash/bg_color=Color(0, 0, 0, 1)
boot_splash/show_image=true
boot_splash/image="res://assets/branding/splash_1080x1920.png"
boot_splash/fullsize=true
boot_splash/use_filter=true
```

单色 adaptive icon 还没做，预设里留空。Android 的 `splash_screen/icon` 也留空，这样系统启动页不会盖掉引擎内的启动图。

## 怎么打一个测试标签

```bash
git tag v0.1.0
git push origin v0.1.0
```

Release 页上会出现 release APK。没有 iOS Secret 时，iOS job 显示跳过签名，整次 Release 流水线仍然是绿的。删掉测试标签和对应 Release 即可，不要把调试签名的包当成上架包。
