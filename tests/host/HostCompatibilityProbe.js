/* Scene-neutral Cavalry host/API compatibility probe. */
(function () {
    "use strict";

    function clean(value) {
        return typeof value === "string" ? value.replace(/^\s+|\s+$/g, "").replace(/\\/g, "/") : "";
    }
    function join(folder, name) {
        folder = clean(folder).replace(/\/+$/, "");
        return folder ? folder + "/" + name : name;
    }

    var tempFolder = "";
    try {
        tempFolder = typeof api.getTempFolder === "function" ? clean(api.getTempFolder()) : "";
    } catch (error) {
        tempFolder = "";
    }
    var scriptLocation = typeof ui !== "undefined" && typeof ui.scriptLocation === "string"
        ? clean(ui.scriptLocation) : "";
    var report = {
        probe: "CavalryToolbarHostProbe",
        version: 1,
        scriptLocation: scriptLocation || null,
        tempFolder: tempFolder || null,
        hasPreferenceObject: typeof api.hasPreferenceObject === "function",
        hasGetPreferenceObject: typeof api.getPreferenceObject === "function",
        hasSetPreferenceObject: typeof api.setPreferenceObject === "function",
        hasLoad: typeof api.load === "function",
        hasEncryptFile: typeof api.encryptFile === "function",
        hasRunFileScript: typeof ui !== "undefined" && typeof ui.runFileScript === "function",
        hasPresentOpenFile: typeof api.presentOpenFile === "function",
        hasPresentSaveFile: typeof api.presentSaveFile === "function",
        hasReadFromFile: typeof api.readFromFile === "function",
        hasListDirectoryPaths: typeof api.listDirectoryPaths === "function",
        hasToNativeFilePath: typeof api.toNativeFilePath === "function"
    };
    var output = join(tempFolder, "CavalryToolbarHostProbe-v01.json");
    var nativeOutput = typeof api.toNativeFilePath === "function" ? api.toNativeFilePath(output) : output;
    if (typeof api.writeToFile !== "function") return "write-unavailable";
    try {
        return api.writeToFile(nativeOutput, JSON.stringify(report), true) === false ? "write-failed" : "finished";
    } catch (error) {
        console.log("Cavalry Toolbar Host Probe: " + error);
        return "write-failed";
    }
})();
