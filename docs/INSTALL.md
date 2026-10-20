# Install Cavalry Toolbar v0.2.0

[中文安装指南](INSTALL.zh-CN.md) · [Project README](https://github.com/luoboruodai/cavalry-toolbar/blob/v0.2.0/README.md)

This guide is also included offline in both installation archives. It covers installation, first-run validation, platform permissions, and recovery. It does not require images or any other online resource.

## 1. Verify your download

Download either `CavalryToolbar-v0.2.0-macOS-universal.zip` or `CavalryToolbar-v0.2.0-Windows-x64.zip`, plus `SHA256SUMS.txt`.

macOS:

```sh
shasum -a 256 CavalryToolbar-v0.2.0-macOS-universal.zip
```

Windows PowerShell:

```powershell
Get-FileHash .\CavalryToolbar-v0.2.0-Windows-x64.zip -Algorithm SHA256
```

Compare the value with the corresponding line in `SHA256SUMS.txt`. Do not install an archive that does not match.

## 2. Back up and copy files

In Cavalry, choose **Scripts → Show Scripts Folder**. Back up any same-named product files before replacing them. Your other scripts, preferences, and projects are not installation targets.

Copy the **contents** of the archive's `Scripts` directory into:

- macOS: `~/Library/Application Support/Cavalry/Scripts/`
- Windows: `%APPDATA%\Cavalry\Scripts\`

The result must include:

- `CavalryToolbar.js`
- `CavalryQuickbarPanel.js`
- `CavalryToolbar_assets/` with the helper for your platform

Do not copy only the two JavaScript files; the native helper is required.

## 3. Configure

1. Open `CavalryToolbar`.
2. Add or scan scripts, select **普通脚本 / api.load** or **UI 面板 / runFileScript**, and bind slots.
3. In Cavalry's Shortcut Manager, assign one unused shortcut to `CavalryQuickbarPanel`.
4. Optional: use `同步快捷键` to generate twelve stable direct-slot launchers. These are separate from the main radial shortcut.

Configuration is stored under `com.cavalrytoolbar.quickbar.v1`. Editing does not execute scripts or modify the Scene.

## 4. Validate before production use

The archive includes scene-neutral `validation/QuickbarSmoke.js` and `validation/HostCompatibilityProbe.js`. Use them before running your own scripts.

- Select with the mouse, wheel, or arrow keys.
- Click or press Enter to run.
- Press `` ` `` / Shift+`` ` `` to switch profiles.
- Press Esc, click the center/right-click, or click outside to cancel.
- Confirm cancellation does not execute the selected script.

Save your project before running any script that may modify it.

## macOS permissions and signatures

- The universal helper is ad-hoc signed, **not notarized**.
- Ordinary script selection and cancellation do not require Accessibility permission.
- A plain shortcut opening a UI panel or the configuration editor requires a one-shot Scripts-menu dispatch. macOS may ask you to enable **CavalryWheel** under **System Settings → Privacy & Security → Accessibility**.
- Rebuilding or replacing the ad-hoc helper changes its CDHash. An old enabled entry can remain visible while no longer matching the current build; remove and re-add the current helper if necessary.
- No security warning or permission check should be bypassed.

## Windows execution and current limits

- The helper uses **Windows PowerShell 5.1 (`powershell.exe`)** and WinForms; PowerShell 7 (`pwsh`) is not the validated runtime. The package does not set `ExecutionPolicy Bypass` or change policy. If policy blocks the helper, review the restriction with your administrator before running it.
- Real Windows CI covers the native helper, not an end-to-end logged-in Cavalry installation. Validate with the included fixtures on your machine.
- Plain-shortcut UI-panel dispatch uses UI Automation bound to the actual calling Cavalry PID. External `.jsc` still needs to be installed in Cavalry Scripts.

## Upgrade or remove

For an upgrade, back up same-named product files, then replace them with the new archive's files. Keep your configuration and other scripts.

To remove the product, delete only the two product JavaScript files and `CavalryToolbar_assets/` after backing them up. Removing the helper does not remove your profiles or other scripts. On macOS, you may also remove the CavalryWheel Accessibility entry yourself if you no longer want it.
