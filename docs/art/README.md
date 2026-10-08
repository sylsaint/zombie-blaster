# 美术

低模 3D、平涂、全项目一张共享调色板贴图。不要实时阴影。脚底用贴在地面上的圆片假阴影，不要用 Decal 节点（Compatibility 渲染器不支持）。

相机是车道后方偏上的追逐机位，灰盒里先固定在车道中线。

目录约定：

- `assets/models/`：网格。杂兵目标约 300–500 三角面，精英 ≤1500，Boss ≤5000
- `assets/textures/`：调色板和顶点动画贴图。导入走 ETC2/ASTC
- `assets/vfx/`：着色器。受击闪白和溶解走实例参数，不要为单个敌人换材质
- `assets/ui/`：界面
- `assets/audio/`：音效与音乐

大文件进仓库前再开 Git LFS。`.gitattributes` 已经把常见二进制标成 binary。
