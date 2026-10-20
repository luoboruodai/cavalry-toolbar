/* Cavalry Toolbar — shortcut-invoked native wheel. Legacy filename preserves the user's menu identity. */
(function () {
    "use strict";
    var KEY = "com.cavalrytoolbar.quickbar.v1", MAX_SLOTS = 12;
    function clean(value) { return typeof value === "string" ? value.replace(/^\s+|\s+$/g, "").replace(/\\/g, "/") : ""; }
    function integer(value) { return typeof value === "number" && isFinite(value) && Math.floor(value) === value; }
    function nameOf(path) { return clean(path).split("/").pop().replace(/\.(js|jsc)$/i, ""); }
    function log(message) { console.log("Cavalry Wheel: " + message); }
    function themeAccent() {
        try {
            if (typeof ui !== "undefined" && typeof ui.getThemeColor === "function") {
                var value = ui.getThemeColor("Accent1");
                if (typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value)) return value;
            }
        } catch (error) { /* older/plain hosts use the measured Cavalry theme fallback */ }
        return "#2fcd71";
    }
    function exists(path) {
        try {
            if (typeof api.isFile === "function") return api.isFile(path);
            if (typeof api.filePathExists === "function") return api.filePathExists(path);
        } catch (error) { return false; }
        return false;
    }
    function issueFor(raw) {
        if (!raw || typeof raw !== "object" || !integer(raw.version)) return "配置不存在或内容损坏，请先在 CavalryToolbar 中绑定脚本。";
        if (raw.version !== 1) return "配置格式" + (raw.version > 1 ? "较新" : "不受支持") + " v" + raw.version + "；未改写配置。";
        if (!Array.isArray(raw.profiles) || !raw.profiles.length || raw.profiles.length > 20) return "配置内容损坏；未改写配置。";
        for (var i = 0; i < raw.profiles.length; i++) {
            var p = raw.profiles[i];
            if (!p || !Array.isArray(p.slots) || (p.modes !== null && typeof p.modes !== "undefined" && !Array.isArray(p.modes))) return "配置内容损坏；未改写配置。";
        }
        if (raw.custom !== null && typeof raw.custom !== "undefined" && !Array.isArray(raw.custom)) return "配置内容损坏；未改写配置。";
        return "";
    }
    var platform = typeof api.getPlatform === "function" ? api.getPlatform() : "";
    var root = typeof ui !== "undefined" && typeof ui.scriptLocation === "string" ? clean(ui.scriptLocation) : "";
    if (!root && typeof api.getHomeFolder === "function") {
        var home = clean(api.getHomeFolder());
        root = platform === "macOS" ? home + "/Library/Application Support/Cavalry/Scripts" : platform === "Windows" ? home + "/AppData/Roaming/Cavalry/Scripts" : "";
    }
    root = root.replace(/\/+$/, "");
    function resolve(path) { path = clean(path); return path.indexOf("@scripts/") === 0 ? root + "/" + path.slice(9) : path; }
    function isSelf(path) {
        var p = clean(path).toLowerCase(), r = root.toLowerCase();
        return p === r + "/cavalryquickbarpanel.js" || p === r + "/cavalrytoolbar.js";
    }
    var state = null;
    try {
        if (typeof api.getPreferenceObject === "function" &&
            (typeof api.hasPreferenceObject !== "function" || api.hasPreferenceObject(KEY))) state = api.getPreferenceObject(KEY);
    } catch (error) { log("配置读取失败：" + error); return "unavailable"; }
    var issue = issueFor(state);
    if (issue) { log(issue); return "incompatible"; }
    if (!root || typeof api.runProcess !== "function" || typeof api.writeToFile !== "function" || typeof api.getTempFolder !== "function") {
        log("此宿主缺少原生轮盘所需的本地进程/文件接口。"); return "unavailable";
    }
    var command = "", args = [], assets = root + "/CavalryToolbar_assets", helperApp = "";
    if (platform === "macOS") {
        helperApp = assets + "/CavalryWheel.app";
        command = "/usr/bin/open";
        if (!exists(helperApp + "/Contents/MacOS/CavalryWheel")) { log("原生轮盘未安装，请复制随包的 CavalryToolbar_assets 文件夹。"); return "missing-helper"; }
    } else if (platform === "Windows") {
        var helper = assets + "/CavalryWheel.ps1";
        if (!exists(helper)) { log("Windows 轮盘未安装，请复制随包的 CavalryToolbar_assets 文件夹。"); return "missing-helper"; }
        command = "powershell.exe";
        args = ["-NoProfile", "-STA", "-File", helper, "-RequestPath"];
    } else { log("不支持的平台：" + platform); return "unavailable"; }
    var active = integer(state.active) && state.active >= 0 && state.active < state.profiles.length ? state.active : 0;
    var request = { version: 1, active: active, reducedMotion: state.reducedMotion === true, timeoutSeconds: 180, accent: "#078430", accentText: themeAccent(), profiles: [] };
    state.profiles.forEach(function (profile) {
        var p = { name: typeof profile.name === "string" && profile.name ? profile.name : "未命名", items: [] };
        for (var slot = 0; slot < Math.min(MAX_SLOTS, profile.slots.length); slot++) {
            var path = resolve(profile.slots[slot]);
            if (!/\.(js|jsc)$/i.test(path)) continue;
            p.items.push({ slot: slot, name: nameOf(path), mode: Array.isArray(profile.modes) && profile.modes[slot] === "ui" ? "ui" : "script", available: exists(path) && !isSelf(path) });
        }
        request.profiles.push(p);
    });
    var requestPath = clean(api.getTempFolder()).replace(/\/+$/, "") + "/CavalryWheel-" + Date.now() + "-" + Math.floor(Math.random() * 1000000) + ".json";
    var responsePath = requestPath.replace(/\.json$/, "-response.json");
    var response = null;
    try {
        if (!api.writeToFile(requestPath, JSON.stringify(request), true)) throw new Error("无法写入轮盘请求");
        if (platform === "macOS") args = ["-W", "-n", "-a", helperApp, "--args", requestPath, responsePath];
        else args.push(requestPath, "-ResponsePath", responsePath);
        // A modal, one-shot selector; there is no polling server, global shortcut hook or resident helper.
        var res = api.runProcess(command, args);
        if (!res || res.error) throw new Error(res && res.error ? res.error : "本地轮盘未返回结果；请检查宿主信任提示");
        var responseText = api.readFromFile(responsePath);
        // Do not mistake the host's process-wait limit for the user closing the selector.
        // Each reader exits within 15 seconds and the native window cancels at 180 seconds.
        for (var waiting = 0; !responseText && waiting < 12; waiting++) {
            if (typeof api.processEvents === "function") api.processEvents();
            // Use an ordinary headless system process, not the GUI app executable: a second
            // process with the wheel bundle identity can steal activation or confuse window routing.
            // The file path is a positional argument, never interpolated into shell source.
            var fileWait = "n=0; while [ \"$n\" -lt 150 ]; do if [ -s \"$1\" ]; then cat \"$1\"; exit 0; fi; sleep 0.1; n=$((n+1)); done; printf '{\"pending\":true}\\n'";
            var waitArgs = platform === "macOS" ? ["-u", "DYLD_INSERT_LIBRARIES", "/bin/sh", "-c", fileWait, "CavalryWheelWait", responsePath]
                : ["-NoProfile", "-File", helper, "-WaitResponsePath", responsePath, "-WaitSeconds", "15"];
            var waitCommand = platform === "macOS" ? "/usr/bin/env" : command;
            var waited = api.runProcess(waitCommand, waitArgs);
            if (!waited || waited.error) throw new Error(waited && waited.error ? waited.error : "轮盘等待未返回结果");
            var pending = waited.output ? JSON.parse(waited.output) : { pending: true };
            if (pending.pending !== true) responseText = waited.output;
            else responseText = api.readFromFile(responsePath);
        }
        if (!responseText) { log("轮盘等待已结束；未执行脚本。"); return "timeout"; }
        response = JSON.parse(responseText);
    } catch (error) { log("轮盘未启动/已取消授权：" + error); return "error"; }
    finally {
        if (typeof api.deleteFilePath === "function") {
            try { api.deleteFilePath(requestPath); api.deleteFilePath(responsePath); } catch (error) { log("临时请求保留在宿主临时目录。"); }
        }
    }
    if (!response || response.version !== 1) { log("轮盘响应格式无效，未执行脚本。"); return "invalid-response"; }
    if (response.action === "cancel") return "cancelled";
    if (response.action === "error") { log(response.message || "原生轮盘错误"); return "error"; }
    var target = "", mode = "script";
    if (response.action === "settings") { target = root + "/CavalryToolbar.js"; mode = "ui"; }
    else if (response.action === "run" && integer(response.profile) && response.profile >= 0 && response.profile < state.profiles.length && integer(response.slot) && response.slot >= 0 && response.slot < MAX_SLOTS) {
        var selected = state.profiles[response.profile];
        target = resolve(selected.slots[response.slot]);
        mode = Array.isArray(selected.modes) && selected.modes[response.slot] === "ui" ? "ui" : "script";
        if (!/\.(js|jsc)$/i.test(target) || isSelf(target)) { log("无效槽位或自调用，未执行脚本。"); return "invalid-slot"; }
    } else { log("轮盘返回了无效选择，未执行脚本。"); return "invalid-response"; }
    if (!target || !exists(target)) { log("脚本已移动或删除，请重新绑定。"); return "missing"; }
    try {
        if (mode === "ui") {
            // Plain shortcut/menu contexts also expose ui.runFileScript, but calling it
            // reentrantly there never delivers a real UI window. Only the configuration
            // editor's explicit marker proves a live UI window context.
            var editorUIContext = false;
            try { editorUIContext = typeof cavalryToolbarWheelUIContext !== "undefined" && cavalryToolbarWheelUIContext === true; } catch (ignored) { editorUIContext = false; }
            if (editorUIContext && typeof ui !== "undefined" && typeof ui.runFileScript === "function") ui.runFileScript(target);
            else if (platform === "macOS" || platform === "Windows") {
                // Obtain the actual invoking process, never guess between running Cavalry versions.
                var parent = platform === "macOS"
                    ? api.runProcess("/usr/bin/env", ["-u", "DYLD_INSERT_LIBRARIES", "/bin/sh", "-c", "printf '%s' \"$PPID\""])
                    : api.runProcess(command, ["-NoProfile", "-Command", "(Get-Process -Id $PID).Parent.Id"]);
                var parentText = parent && !parent.error && typeof parent.output === "string" ? clean(parent.output) : "";
                var hostPID = /^[1-9][0-9]*$/.test(parentText) ? Number(parentText) : 0;
                if (!integer(hostPID) || hostPID < 1 || hostPID > 2147483647) {
                    log("无法确认发起调用的 Cavalry 进程；未选择其他实例代替，也未以普通模式执行 UI 脚本。"); return "ui-unavailable";
                }
                if (platform === "Windows" && !exists(assets + "/UIRelay.js")) {
                    log("Windows UI 中继未安装，请复制随包的 CavalryToolbar_assets 文件夹。"); return "missing-helper";
                }
                var dispatchPath = requestPath.replace(/\.json$/, "-ui.json");
                var dispatchResponsePath = requestPath.replace(/\.json$/, "-ui-response.json");
                if (!api.writeToFile(dispatchPath, JSON.stringify({ version: 1, hostPID: hostPID, target: target }), true)) throw new Error("无法写入 UI 分派请求");
                // No -W: Cavalry must leave this callback before the helper presses its Scripts menu.
                // The one-shot helper consumes its request and removes only its owned temporary relay.
                var launched;
                if (platform === "macOS") launched = api.runProcess("/usr/bin/open", ["-n", "-a", helperApp, "--args", "--dispatch-ui", dispatchPath]);
                else launched = api.runProcess(command, ["-NoProfile", "-STA", "-File", helper, "-DispatchUI", dispatchPath, "-DispatchResponsePath", dispatchResponsePath]);
                if (!launched || launched.error) {
                    if (typeof api.deleteFilePath === "function") { api.deleteFilePath(dispatchPath); api.deleteFilePath(dispatchResponsePath); }
                    throw new Error(launched && launched.error ? launched.error : "UI 分派助手未启动");
                }
                if (platform === "Windows") {
                    var waited = api.runProcess(command, ["-NoProfile", "-File", helper, "-WaitResponsePath", dispatchResponsePath, "-WaitSeconds", "15"]);
                    var dispatchResult = null;
                    try { if (waited && typeof waited.output === "string" && waited.output) dispatchResult = JSON.parse(waited.output); } catch (ignored) { dispatchResult = null; }
                    if (typeof api.deleteFilePath === "function") { api.deleteFilePath(dispatchPath); api.deleteFilePath(dispatchResponsePath); }
                    if (!dispatchResult || dispatchResult.action !== "ui-dispatch") { log("UI 分派没有返回有效结果；未执行替代路径。"); return "error"; }
                    if (["menu-invoked", "evaluated"].indexOf(dispatchResult.status) < 0) {
                        log(dispatchResult.message || "UI 分派失败；未执行替代路径。"); return "error";
                    }
                }
                log("已请求当前 Cavalry 的原生菜单 UI 分派；请检查面板结果。这不是脚本成功证明。");
                return "ui-dispatch-pending";
            } else { log("此入口没有 UI 脚本上下文；请从配置编辑器的「呼出轮盘」运行 UI 面板。此平台快捷键的 UI 分派尚待接通。"); return "ui-unavailable"; }
        } else if (typeof api.load === "function") api.load(target);
        else throw new Error("脚本启动接口不可用");
        log(/\.jsc$/i.test(target) ? ".jsc invoked; check the host result" : "invoked " + nameOf(target));
        return "finished";
    } catch (error) { log("invocation error (the script may have run): " + error); return "error"; }
})();
