# 测试

自动化在桌面跑，真机清单以后写在这里。

现在能跑的：

- `./tools/run_tests.sh`：无头跑 GUT。示例测试覆盖车道拖动的位移和夹紧
- `./tools/smoke_main.sh`：无头启动主场景，日志里出现 `ERROR:` 或 `WARNING:` 就失败
- GitHub Actions（`.github/workflows/test.yml`）在 push 和 pull request 上做同样的事

真机压测包的安装和要记的数在 [device-test.md](device-test.md)。低端机是 Helio G85 / 骁龙 680，中端机是骁龙 7 Gen 1，标准在 [m1-test-plan.md](m1-test-plan.md)。
