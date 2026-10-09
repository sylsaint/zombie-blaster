# 真机压测（Android Profile APK）

这个包用来在手机上记帧时间。它用 **release 导出模板**，不是 debug，所以帧时间可以和 30 帧目标（33.3 ms）比。包名是 `com.zombieblaster.game.profile`，和正式包 `com.zombieblaster.game` 可以同时装。启动器名字是 **Zombie Blaster Profile**。

它只作为 Actions artifact `android-profile-apk` 上传。PR（改了 `.github/workflows/release.yml` 或 `export_presets.cfg`）和 `v*` 标签都会打这个包。**不会**挂到 GitHub Release。

预设名是 `Android Profile`，feature tag 是 `profile`。带这个 tag 的包启动后直接进入 `scenes/debug/stress_test.tscn`：180 个行走、120 个快跑、3 个精英、1 个 Boss（300 个小怪）。预热之后记 **600** 帧再停。600 帧和 [#17](https://github.com/sylsaint/zombie-blaster/issues/17)、[#25](https://github.com/sylsaint/zombie-blaster/issues/25) 的窗口一样。`tests/`、`addons/gut/`、`docs/`、`tools/` 不进这个包。

## 安装

1. 打开对应的 Actions run，下载 artifact `android-profile-apk`（不要下 GitHub Release 里的包）。
2. 解压得到 `zombie-blaster-<tag>-android-profile.apk`。
3. 安装：`adb install -r zombie-blaster-<tag>-android-profile.apk`
4. 打开 **Zombie Blaster Profile**。不要打开正式的 Zombie Blaster。

跑完之后屏幕上是大字结果。**再跑一次** 会重跑这 600 帧。**Share** 把同一份 JSON 复制到剪贴板。

## 要记的数

| 屏幕 | JSON 字段 | 怎么用 |
| --- | --- | --- |
| logic avg | `logic_avg_ms` | 玩法逻辑平均。#25 在 QA 虚拟机上是 4.89 ms。真机应低于那台机器 |
| logic p99 | `logic_p99_ms` | #25 的 6 ms 线。QA 虚拟机是 7.24 ms，已经超过。Helio G85 / 骁龙 680 上的这个数决定 #25 还要不要做 |
| frame avg | `frame_avg_ms` | 整帧平均。30 帧目标是 33.3 ms。#17 无头 debug 的整帧 avg 约 15.6 ms，不能和这个 release 包比绝对值 |
| 1% low | `fps_1pct_low` | #17 的卡帧指标。无头当时是 9.3 / 8.4 fps。低端机验收是 1% low ≥ 25（`m1-test-plan.md` 的 PF-04） |
| draws | `draw_calls` | 绘制调用。批次数不该跟着人数往上爬（PF-03） |
| tris | `triangles` | 三角形，留下真机基线 |
| memory | `memory_static_mb` | 静态内存。#17 无头记过 54 MB。PF-04 上限 500 MB |

逻辑远小于整帧、同时 1% low 很低时，卡顿不在 `combat_sim`，按 #17 记成渲染或驱动问题。logic p99 和机型贴回 #25。

## 结果文件

跑完写入 `user://stress_stats.json`。里面有上面 7 个数，加上 `timestamp`（UTC，带 `Z`）和 `device_model`（`OS.get_model_name()`）。Share 复制的就是这个文件的内容。再跑一次会覆盖它。

不靠剪贴板时：

```bash
adb shell run-as com.zombieblaster.game.profile cat files/stress_stats.json
```

机型按 `docs/qa/m1-test-plan.md`：低端 Helio G85 / 骁龙 680（4GB），中端骁龙 7 Gen 1。低端要稳定 30 帧、1% low ≥ 25、内存 ≤ 500MB。中端要稳定 60 帧。
