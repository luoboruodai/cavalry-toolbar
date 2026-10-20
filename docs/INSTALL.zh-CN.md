# Cavalry Toolbar v0.1.0 安装指南

[English installation](INSTALL.md) · [项目说明](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.1.0/README.zh-CN.md)

本指南同时收录在两个安装包中，可离线阅读，涵盖安装、首次验收、平台权限与恢复。理解这些步骤不需要图片或其他在线资源。

## 1. 校验下载包

下载 `CavalryToolbar-v0.1.0-macOS-universal.zip` 或 `CavalryToolbar-v0.1.0-Windows-x64.zip`，以及 `SHA256SUMS.txt`。

macOS：

```sh
shasum -a 256 CavalryToolbar-v0.1.0-macOS-universal.zip
```

Windows PowerShell：

```powershell
Get-FileHash .\CavalryToolbar-v0.1.0-Windows-x64.zip -Algorithm SHA256
```

与 `SHA256SUMS.txt` 中对应行比较。校验值不一致时不要安装。

## 2. 备份并复制文件

在 Cavalry 中选择 **Scripts → Show Scripts Folder**。替换同名产品文件前先备份。你的其他脚本、偏好设置和工程都不是安装目标。

将压缩包内 `Scripts` 目录的**内容**复制到：

- macOS：`~/Library/Application Support/Cavalry/Scripts/`
- Windows：`%APPDATA%\Cavalry\Scripts\`

最终结果必须包含：

- `CavalryToolbar.js`
- `CavalryQuickbarPanel.js`
- 对应平台的 `CavalryToolbar_assets/` 助手目录

不要只复制两个 JavaScript 文件，原生助手是必需的。

## 3. 配置

1. 打开 `CavalryToolbar`。
2. 添加／扫描脚本，选择 **普通脚本 / api.load** 或 **UI 面板 / runFileScript**，绑定槽位。
3. 在 Cavalry Shortcut Manager 中为 `CavalryQuickbarPanel` 分配一个未冲突快捷键。
4. 可选：用 `同步快捷键` 生成 12 个稳定的单槽直达脚本；它们与主轮盘入口不同。

配置保存在 `com.cavalrytoolbar.quickbar.v1`。编辑不会执行脚本或修改 Scene。

## 4. 先验收再用于生产

包内包含场景中立的 `validation/QuickbarSmoke.js` 和 `validation/HostCompatibilityProbe.js`，请先使用它们。

- 鼠标、滚轮或方向键选择。
- 点击或回车运行。
- `` ` ``／Shift+`` ` `` 切换配置。
- Esc、中心点击、右键或点击外部取消。
- 确认取消不会执行选中的脚本。

运行任何可能修改工程的脚本前，请先保存。

## macOS 权限与签名

- 通用助手为 ad-hoc 开发签名，**未公证**。
- 普通脚本选择与取消不需要辅助功能权限。
- 普通快捷键打开 UI 面板或配置页需要一次性 Scripts 菜单分派。macOS 可能要求在 **系统设置 → 隐私与安全性 → 辅助功能** 中允许 **CavalryWheel**。
- 重建或替换 ad-hoc 助手会改变 CDHash。旧的“已开启”记录可能仍存在但不再匹配当前构建；必要时移除并重新添加当前助手。
- 不绕过安全警告或权限检查。

## Windows 执行与当前限制

- 助手使用 **Windows PowerShell 5.1（powershell.exe）** 与 WinForms；PowerShell 7（pwsh）不是本次验收运行时，不设置 `ExecutionPolicy Bypass`，不修改策略。如果策略阻止运行，请先与管理员核对限制。
- 真实 Windows CI 覆盖原生助手，但不等于已登录 Cavalry 宿主内的端到端验收。请在自己的机器上先运行包内夹具。
- Windows 尚未实现普通快捷键的 UI 面板分派，请从配置编辑器打开 UI 面板。

## 升级或移除

升级时先备份同名产品文件，再使用新包替换，保留你的配置和其他脚本。

移除产品时，备份后只删除两个产品 JavaScript 文件与 `CavalryToolbar_assets/`。删除助手不会删除你的配置或其他脚本。macOS 如不再需要，也可自行移除 CavalryWheel 的辅助功能记录。
