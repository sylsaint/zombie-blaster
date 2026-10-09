# 真机压测（Android Profile APK）

这个包用 **release 导出模板**，不是 debug。包名是 `com.zombieblaster.game.profile`，和正式包 `com.zombieblaster.game` 可以同时装。启动器名字是 **高速打僵尸 Profile**。

它只作为 Actions artifact `android-profile-apk` 上传。PR（改了 `.github/workflows/release.yml` 或 `export_presets.cfg`）和 `v*` 标签都会打这个包。**不会**挂到 GitHub Release。

预设名是 `Android Profile`，feature tag 是 `profile`。带这个 tag 的包启动后直接进入 `scenes/debug/stress_test.tscn`：180 个行走、120 个快跑、3 个精英、1 个 Boss（300 个小怪）。预热之后记 **600** 帧再停。600 帧和 [#17](https://github.com/sylsaint/zombie-blaster/issues/17)、[#25](https://github.com/sylsaint/zombie-blaster/issues/25) 的窗口一样。`tests/`、`addons/gut/`、`docs/`、`tools/` 不进这个包。

## 安装（不用 adb）

1. 手机浏览器登录 GitHub，打开这次 Actions run。
2. 下载 artifact `android-profile-apk` 的 zip。不要下 GitHub Release 里的包。
3. 解压 zip。
4. 点 `zombie-blaster-<tag>-android-profile.apk`。
5. 系统如果拦住，允许这个浏览器或文件管理器「安装未知应用」，再点一次 APK。
6. 打开 **高速打僵尸 Profile**。不要打开正式的 **高速打僵尸**。

电脑上也可以 `adb install -r` 同一个 APK。

## 每台机器连跑三次

打开之后它自己跑完第一次。然后点 **再跑一次**，不要杀进程，连续跑满三次。屏幕左上角的 `run 1` / `run 2` / `run 3` 就是第几次。**只记第三次**，用来看发热之后有没有降频。Share 复制出去的 JSON 里有同样的 `run`。

## 要记的数

| 屏幕 | JSON 字段 | 怎么用 |
| --- | --- | --- |
| logic avg | `logic_avg_ms` | 玩法逻辑平均。#25 在 QA 虚拟机上是 4.89 ms。真机应低于那台机器 |
| logic p99 | `logic_p99_ms` | **判定项。** #25 的 6 ms 线。QA 虚拟机是 7.24 ms，已经超过。Helio G85 / 骁龙 680 上的这个数决定 #25 还要不要做 |
| frame avg | `frame_avg_ms` | **只作参考，不作为通过或失败。** 垂直同步把帧时间托在刷新间隔上：60 Hz 时下限是 16.7 ms，30 Hz 时是 33.3 ms。平均数贴着这个下限，不说明还有多少余量。#17 无头 debug 的整帧 avg 约 15.6 ms，也不能和这个数比绝对值 |
| 1% low | `fps_1pct_low` | **判定项。** #17 的卡帧指标。无头当时是 9.3 / 8.4 fps。低端机验收是 1% low ≥ 25（`m1-test-plan.md` 的 PF-04） |
| draws | `draw_calls` | 绘制调用。批次数不该跟着人数往上爬（PF-03） |
| tris | `triangles` | 三角形，留下真机基线 |
| Godot static (not PSS) | `memory_static_mb` | 引擎静态内存，**不是整个进程**。#17 无头记过约 54 MB。不能拿它去对 PF-04 的 500 MB |
| device RAM | `device_physical_mb` / `device_available_mb` | `OS.get_memory_info()` 读到的整机物理内存和可用内存。用来确认是不是 4 GB 那台机器。没有读到时这两个字段是 -1，屏幕上不显示。这也不是进程 PSS |
| （不在屏幕上）TOTAL PSS | 无 | **PF-04 的 500 MB 指这个。** 第三次跑到结果画面时，在电脑上执行下面的命令，记 `TOTAL PSS` |

```bash
adb shell dumpsys meminfo com.zombieblaster.game.profile
```

`dumpsys` 不要求应用可调试。release 包也可以查。精确的 TOTAL PSS 仍然要这条 adb 命令。

没有电脑时：打开开发者选项，进「内存」（有的机型叫「正在运行的服务」）。里面能看到这个应用的平均内存和最高内存。这是近似值，只够粗对一下 500 MB 那条线，不能代替 TOTAL PSS。

屏幕下方有一行说明，和上面 frame avg 的规则一样：60 Hz 下限 16.7 ms，是否通过只看 1% low 和 logic p99。

逻辑远小于整帧、同时 1% low 很低时，卡顿不在 `combat_sim`，按 #17 记成渲染或驱动问题。把第三次的 logic p99、1% low、机型和 TOTAL PSS 贴回 #25 / #17。

机型按 `docs/qa/m1-test-plan.md`：低端 Helio G85 / 骁龙 680（4GB），中端骁龙 7 Gen 1。低端要稳定 30 帧、1% low ≥ 25、**TOTAL PSS ≤ 500MB**。中端要稳定 60 帧。

## 结果怎么带走

**Share 是唯一路径。** 它把同一份 JSON 复制到剪贴板。JSON 里有屏幕上的数、`run`、UTC `timestamp`（带 `Z`）和 `device_model`（`OS.get_model_name()`）。

没有「保存到下载」按钮。Godot 4.7.2 的 `OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)` 给出的是公共 Download 目录的普通文件路径，引擎对它走直接写文件，不走 MediaStore。导出模板的 targetSdk 是 36，`requestLegacyExternalStorage` 是 false，也没有存储权限。API 29 及以上会拒绝这次写入，所以不能靠这条路径把 JSON 存进下载目录。

应用还会把同一份 JSON 写到自己的私有目录 `user://stress_stats.json`。这是 release 包，不可调试，读不出这个私有文件。不要用 `adb shell run-as`。
