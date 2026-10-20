// Generated only for a selected external .js UI. Evaluated by Cavalry's own UI engine.
var cavalryToolbarUIRelayTask = null;
(function () {
    if (false) ui.show(); // Declare UI mode; the selected script controls the sole window.
    var request = __CAVALRY_WHEEL_DISPATCH__;
    cavalryToolbarUIRelayTask = new api.Timer({ onTimeout: function () {
    cavalryToolbarUIRelayTask.stop();
    var nativeUI = ui, panelUI;
    var result = { version: 1, status: "error" };
    try {
        if (typeof Proxy !== "function") throw new Error("This host cannot preserve an external UI script's location.");
        // Proxy a plain object, not the native read-only object: scriptLocation on the
        // latter cannot be changed and may be a non-configurable native property.
        panelUI = new Proxy({}, {
            get: function (_, key) {
                if (key === "scriptLocation") return request.directory;
                var value = nativeUI[key];
                return typeof value === "function" ? value.bind(nativeUI) : value;
            },
            set: function (_, key, value) {
                if (key === "scriptLocation") return false;
                nativeUI[key] = value; return true;
            },
            has: function (_, key) { return key === "scriptLocation" || key in nativeUI; },
            ownKeys: function () { return Object.getOwnPropertyNames(nativeUI); },
            getOwnPropertyDescriptor: function (_, key) {
                var descriptor = Object.getOwnPropertyDescriptor(nativeUI, key);
                if (!descriptor) return undefined;
                return { configurable: true, enumerable: descriptor.enumerable,
                    get: function () { return panelUI[key]; },
                    set: function (value) { panelUI[key] = value; } };
            }
        });
        var source = api.readFromFile(request.target);
        if (typeof source !== "string") throw new Error("Cannot read the selected UI script.");
        // A dedicated UI engine executes the chosen source, never a plain api.load.
        (function (ui) { eval(source); })(panelUI);
        result.status = "evaluated"; // Not a claim that the script's business action succeeded.
    } catch (error) {
        result.message = String(error);
        console.log("Cavalry Wheel UI: " + result.message);
    }
    api.writeToFile(request.receipt, JSON.stringify(result), true);
    cavalryToolbarUIRelayTask = null;
    } });
    cavalryToolbarUIRelayTask.setInterval(1);
    cavalryToolbarUIRelayTask.setRepeating(false);
    cavalryToolbarUIRelayTask.start();
    return "scheduled";
})();
