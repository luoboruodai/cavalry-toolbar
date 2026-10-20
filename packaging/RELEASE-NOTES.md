# Cavalry Toolbar v0.1.0

[English](#english) · [中文](#中文)

## English

Cavalry Toolbar is a native radial script launcher and profile editor for Cavalry 2.8. This is the first public development release, with installation archives for macOS and Windows.

### Download

- **macOS 12+ (Apple Silicon / Intel):** `CavalryToolbar-v0.1.0-macOS-universal.zip`
- **Windows 10/11 x64:** `CavalryToolbar-v0.1.0-Windows-x64.zip`
- **Checksums:** `SHA256SUMS.txt`

Use these installation archives, not GitHub's automatic Source code ZIP. Follow [Installation](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.1.0/docs/INSTALL.md) or [安装指南](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.1.0/docs/INSTALL.zh-CN.md).

### Highlights

- Twelve stable slots, multiple profiles, circular arc labels, and a native radial launcher.
- Script library, drag-to-swap, import/export, and scene-neutral validation fixtures.
- Hover/press feedback, successful-swap center pulse, and Filee-inspired per-slice close animation.
- Reduced-motion support and no resident service or global keyboard hook.
- English and Chinese documentation, with bilingual offline installation guides in every archive.

### Verification

Release jobs require source tests, macOS AppKit event-model checks, real Windows WinForms checks, universal packaging, and archive byte verification to pass. `SHA256SUMS.txt` is generated from the exact uploaded archives.

### Platform limits

- The macOS helper is ad-hoc signed and not notarized. Accessibility permission is needed only for plain-shortcut UI-panel/configuration dispatch.
- Windows native helper checks run on real Windows CI, but an end-to-end logged-in Cavalry host test on Windows is not covered. Plain-shortcut UI-panel dispatch is not implemented on Windows; use the configuration editor. The native Windows wheel uses static feedback; Filee-inspired per-slice close animation is macOS-only.
- Validate with the included scene-neutral fixtures before running production scripts. Save your Scene first.

## 中文

Cavalry Toolbar 是面向 Cavalry 2.8 的原生脚本轮盘与配置编辑器。这是首个公开开发版本，提供 macOS 与 Windows 安装包。

### 下载

- **macOS 12+（Apple Silicon / Intel）：** `CavalryToolbar-v0.1.0-macOS-universal.zip`
- **Windows 10/11 x64：** `CavalryToolbar-v0.1.0-Windows-x64.zip`
- **校验值：** `SHA256SUMS.txt`

请使用这些安装附件，不要把 GitHub 自动生成的 Source code ZIP 当作安装包。按照 [Installation](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.1.0/docs/INSTALL.md) 或 [安装指南](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.1.0/docs/INSTALL.zh-CN.md) 操作。

### 主要内容

- 12 个稳定槽位、多配置、同心圆弧名称与原生轮盘。
- 脚本库、拖动交换、导入／导出和场景中立验收夹具。
- 悬停／按下反馈、成功交换中心脉冲，以及 Filee 式逐片退场。
- 支持减少动效，不安装常驻服务或全局键盘监听。
- 中英文文档，每个安装包都包含双语离线安装指南。

### 验证

发布任务要求源码测试、macOS AppKit 事件模型、真实 Windows WinForms 检查、通用打包和归档字节校验全部通过。`SHA256SUMS.txt` 由实际上传的安装包生成。

### 平台限制

- macOS 助手为 ad-hoc 开发签名，未公证。只有普通快捷键的 UI 面板／配置分派需要辅助功能权限。
- Windows 原生助手在真实 Windows CI 中验证，但尚未覆盖已登录 Cavalry 宿主内的端到端测试。Windows 普通快捷键的 UI 面板分派尚未实现，请从配置编辑器打开。Windows 原生轮盘目前使用静态反馈，Filee 式逐片退场仅适用于 macOS。
- 请先使用包内场景中立夹具验收，再运行生产脚本，并提前保存 Scene。
