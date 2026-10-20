# Cavalry Toolbar

A native radial script launcher and profile editor for **Cavalry 2.8**. Keep twelve stable script slots one shortcut away, with circular arc labels, a Filee-inspired close animation, and a reduced-motion fallback.

[中文说明](README.zh-CN.md) · [Download v0.1.0](https://github.com/luoboruodai/cavalry-toolbar/releases/tag/v0.1.0) · [Installation](docs/INSTALL.md) · [CI](https://github.com/luoboruodai/cavalry-toolbar/actions/workflows/ci-release.yml)

## What it does

- **Twelve stable slots and multiple profiles:** bind ordinary `.js` / `.jsc` scripts or UI panels without changing their slot numbers.
- **Native radial launcher:** circular arc labels, mouse/wheel/arrow selection, click/Enter to run, and `` ` `` / Shift+`` ` `` to switch profiles.
- **Configuration editor:** scan or add scripts, edit profiles, drag bound slots to swap them, and import/export configuration.
- **Purposeful motion:** hover/press feedback, a successful-swap center pulse, and per-slice shrink/twist/fade on pointer close. Reduced motion keeps state changes immediate.
- **Bounded, local execution:** no resident service, no global keyboard hook, and no script source or executable paths sent to the native helper.

## Downloads

| Package | Platform | Contents |
| --- | --- | --- |
| `CavalryToolbar-v0.1.0-macOS-universal.zip` | macOS 12+, Apple Silicon and Intel | Both editor scripts, universal AppKit helper, validation fixtures, bilingual offline guides |
| `CavalryToolbar-v0.1.0-Windows-x64.zip` | Windows 10/11 x64 | Both editor scripts, PowerShell/WinForms helper, validation fixtures, bilingual offline guides |
| `SHA256SUMS.txt` | All | SHA-256 for the two installation archives |

**Use the installation archives, not GitHub's automatic “Source code” ZIP, for a ready-to-install package.**

## Platform notes

### macOS

- Universal `arm64` + `x86_64` AppKit helper.
- The helper is **ad-hoc signed and not notarized**. Do not bypass macOS security warnings.
- Accessibility permission is needed **only** when a plain shortcut must open a UI panel or the configuration editor through Cavalry's Scripts menu. Ordinary script selection and cancellation do not need it.
- Rebuilding or replacing the ad-hoc helper can change its CDHash; an older enabled Accessibility entry may no longer match. Re-add the current helper if needed.

### Windows

- Windows PowerShell 5.1 (`powershell.exe`) and .NET Framework WinForms; no `ExecutionPolicy Bypass` and no policy changes. PowerShell 7 (`pwsh`) is not the validated runtime.
- Real Windows CI covers native helper launch, keyboard selection, profile switching, cancellation, and bounded response waiting.
- An end-to-end test inside a logged-in Cavalry installation on Windows is **not yet covered**. Validate with the included scene-neutral fixtures before running production scripts.
- Plain-shortcut UI-panel dispatch is not implemented on Windows. Open UI panels from the configuration editor instead.

## Install and use

1. Read [Installation](docs/INSTALL.md) or [安装指南](docs/INSTALL.zh-CN.md), then copy the package's `Scripts` contents into Cavalry's Scripts directory.
2. Open `CavalryToolbar`, add or scan scripts, choose a run mode, and bind slots.
3. In Cavalry's Shortcut Manager, assign one shortcut to `CavalryQuickbarPanel`.
4. Select with the mouse, wheel, or arrow keys. Click or press Enter to run. Press Esc, click the center/right-click, or click outside to cancel.
5. Press `` ` `` for the next profile and Shift+`` ` `` for the previous one.

**Editing a profile does not execute scripts or modify the Scene. Your own scripts may modify the Scene, so save your project before running them.**

## Build and test

Requirements for development: Node.js, Python 3, and Apple Command Line Tools on macOS. Windows helper tests run in PowerShell on Windows.

```sh
node scripts-build.mjs
native/macos/build.sh
node --test tests/host-smoke.test.mjs tests/toolbar.test.mjs tests/ui-relay.test.mjs tests/wheel.test.mjs
tests/macos/run.sh
python3 packaging/build_release.py
```

On Windows:

```powershell
tests/windows/run.ps1
```

The release workflow runs source tests, AppKit event-model checks, real WinForms checks, universal packaging, archive byte verification, and release upload only after all required jobs pass.

## Security and privacy

- The native helper receives display names, slot numbers, modes, and availability only. It returns an action, profile index, and slot index—not an executable path.
- Cavalry validates the returned indices against its own configuration before loading a script.
- No network service, telemetry, background daemon, or global keyboard listener is installed.
- On macOS, an outside-mouse-down monitor exists only while the wheel is open and is removed when it closes. Accessibility-based UI dispatch is a separate one-shot action scoped to Cavalry's Scripts menu.

## License

[MIT](LICENSE) © 2026 luoboruodai
