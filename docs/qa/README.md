# 测试

自动化在桌面跑，真机清单以后写在这里。

现在能跑的：

- `./tools/run_tests.sh`：无头跑 GUT。示例测试覆盖车道拖动的位移和夹紧
- `./tools/smoke_main.sh`：无头启动主场景，日志里出现 `ERROR:` 或 `WARNING:` 就失败
- GitHub Actions（`.github/workflows/test.yml`）在 push 和 pull request 上做同样的事

之后补：低端 Android 机型表、竖屏长宽比（约 9:16 到 9:21）、发热和同屏人数。设计文档未定之前，不写玩法用例。
