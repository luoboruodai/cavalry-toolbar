# Cavalry Toolbar v0.2.0

[English](#english) · [中文](#中文)

## English

This release completes the Windows shortcut UI dispatch and native wheel motion, while preserving the macOS universal helper and bilingual offline installation guides.

### Download

- **macOS 12+ (Apple Silicon / Intel):** `CavalryToolbar-v0.2.0-macOS-universal.zip`
- **Windows 10/11 x64:** `CavalryToolbar-v0.2.0-Windows-x64.zip`
- **Checksums:** `SHA256SUMS.txt`

Use these installation archives, not GitHub's automatic Source code ZIP. Follow [Installation](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.2.0/docs/INSTALL.md) or [安装指南](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.2.0/docs/INSTALL.zh-CN.md).

### New in v0.2.0

- Windows plain-shortcut UI-panel and configuration dispatch through UI Automation bound to the actual calling Cavalry PID.
- Windows hover/press feedback and Filee-inspired per-slice shrink/twist/fade close animation, with reduced-motion fallback.
- Selection responses are written before the visual close; external JS relay files are removed after dispatch.
- External encrypted `.jsc` fails closed and must be installed in Cavalry Scripts rather than relayed as source.
- Windows validation now covers 41 native WinForms, motion, and isolated UI Automation assertions.

### Verification and limits

- Source tests: 73/73. macOS AppKit: 177/177. Menu dispatch: 19/19. Windows: 41/41.
- CI builds both installation archives and verifies members, CRC, and SHA-256. Remote release assets are checked against the CI package.
- macOS helper remains ad-hoc signed and not notarized. Windows validation uses Windows PowerShell 5.1; `pwsh` is not validated.
- An end-to-end logged-in Cavalry installation on Windows is not covered. The dispatch evidence uses an isolated `Cavalry.exe` host and real UI Automation, not a production Cavalry project.

## 中文

本版本补齐 Windows 快捷键 UI 分派与原生轮盘动效，同时保留 macOS 通用助手和双语离线安装指南。

### 下载

- **macOS 12+（Apple Silicon / Intel）：** `CavalryToolbar-v0.2.0-macOS-universal.zip`
- **Windows 10/11 x64：** `CavalryToolbar-v0.2.0-Windows-x64.zip`
- **校验值：** `SHA256SUMS.txt`

请使用安装附件，不要把 GitHub 自动生成的 Source code ZIP 当作安装包。按照 [Installation](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.2.0/docs/INSTALL.md) 或 [安装指南](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.2.0/docs/INSTALL.zh-CN.md) 操作。

### v0.2.0 新增

- Windows 普通快捷键的 UI 面板与配置分派，使用绑定实际调用 Cavalry PID 的 UI Automation。
- Windows 悬停／按下反馈和 Filee 式逐片缩小／扭转／淡出退场，支持减少动效。
- 选择响应先于视觉退场写回；外部 JS 中继在分派后删除。
- 外部加密 `.jsc` 必须安装到 Cavalry Scripts，不能以源码中继代替。
- Windows 验收新增 41 项原生 WinForms、动效与隔离 UI Automation 断言。

### 验证与限制

- 源码测试：73/73；macOS AppKit：177/177；菜单分派：19/19；Windows：41/41。
- CI 构建两个安装包并核对成员、CRC 与 SHA-256，Release 附件与 CI 原始产物一致。
- macOS 助手仍为 ad-hoc 开发签名，未公证。Windows 验收使用 Windows PowerShell 5.1，未验证 `pwsh`。
- 尚未覆盖已登录 Cavalry 宿主内的 Windows 端到端测试；分派证据来自隔离 `Cavalry.exe` 与真实 UI Automation，不是生产工程。
