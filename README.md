# 阴阳省电 · YinYang Saver (WoW Forever)

面向 **WoW Forever (Interface 16001)** 的一键挂机省电插件，基于 [Forever Profiles](https://github.com/jBeyondstars/ForeverProfile) 修改。

## 安装及使用

将整个插件保存为 `_forever_/Interface/AddOns/ForeverProfiles`，确保 `ForeverProfiles.toc` 位于该文件夹下；重启游戏后启用插件。

- **阳（默认）**：保持你的正常画质。
- **点击小地图左上侧阴阳图标 → 阴**：自动备份当前画质，将普通与团队画质调为最低档，降低渲染比例、抗锯齿，并把前后台 FPS 都限制为 **8**。
- **再次点击 → 阳**：恢复切换前保存的画质和 FPS。

不需要保存两套配置；没有设置窗口、收藏栏、快捷键或常驻定时轮询。不会调整 Windows 分辨率、显示器刷新率或电源计划。

## 备份与恢复

原始画质快照存入 `ForeverYinYangDB`。正常退出游戏或 `/reload` 会保存快照，下次登录后可以继续点击阴阳按钮恢复。游戏异常结束时，最近的 SavedVariables 改动可能丢失。

若部分设置被客户端或另一个插件拒绝，会在聊天框提示。恢复没有完全成功时原始备份不会删除，再点图标即可重试。插件只对当前客户端确实提供的图形项进行操作；游戏内实际效果及功耗仍需在 WoW Forever 客户端测试。

## 文件

- `Graphics.lua`：沿用原插件的图形 CVars 白名单、快照及写入校验。
- `YinYang.lua`：阴阳双态、小地图按钮与跨重载恢复。
- `Media/YinYang.tga`：自带阴阳图案。
- `tests/test_toggle.lua`：无游戏客户端的状态切换冒烟测试。

原有多画质管理界面、收藏栏及快捷键已从插件中移除。

> 原项目未包含明确许可证。此仓库保留 GitHub Fork 关系；若计划独立公开再分发，建议先征得原作者授权。
