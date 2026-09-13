# 翡翠纷争（游戏客户端）

Godot 4.5.2 开发的 720×1280 竖屏手机自动对战策略游戏客户端。

## 当前内容

- 自动对战、弹道首碰撞、资源采集、复活与战斗回放
- 自然语言团队策略编辑与 Strategy Runtime 客户端执行/回放
- 21×35 独立经营 LandGrid 的小岛地图
- 岛屿工人独立 FIFO 队列、空地移动、采集/播种/收获/制作表现
- 英雄成长、地块解锁、库存与云端账号界面

## 运行

1. 使用 Godot `4.5.2` 打开 `project.godot`。
2. 主场景为 `main.tscn`。
3. Web 导出使用 `export_presets.cfg`。

Web 客户端默认请求同源 `/game_1/api/v1`。本地运行默认请求 `http://127.0.0.1:19031`，完整联网功能需要同时启动配套服务端仓库 `game1_server`。

## 测试

```bash
/opt/godot/4.5.2/godot --headless --editor --path . --quit
/opt/godot/4.5.2/godot --headless --path . --script res://tests/phase1_phase3_ui_test.gd
/opt/godot/4.5.2/godot --headless --path . --script res://tests/replay_client_test.gd
```

需要截图的 UI 测试应在具有图形环境或 `xvfb-run` 的环境中执行。

## 仓库边界

本仓库包含客户端场景、脚本、素材、共享配置和客户端测试，不包含服务端密钥、数据库凭据、Python 虚拟环境或部署机器配置。
