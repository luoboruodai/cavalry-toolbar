// Dispatch tests use a fake menu adapter, owned synthetic files, and no real host/AX actions.
final class FakeCavalryMenu: CavalryMenuAccess {
    var trusted = true
    var validHost = true
    var invocations: [(Int32, [String])] = []
    var onInvoke: (([String]) throws -> Void)?
    func isCavalry(pid: Int32) -> Bool { validHost && pid == 12345 }
    func invoke(pid: Int32, components: [String]) throws {
        invocations.append((pid, components)); try onInvoke?(components)
    }
}
do {
    let start = checkCount
    let fm = FileManager.default
    let base = fm.temporaryDirectory.appendingPathComponent("WheelUIDispatchTests-" + UUID().uuidString)
    defer { try? fm.removeItem(at: base) }
    let root = base.appendingPathComponent("Scripts"), external = base.appendingPathComponent("External '中文"), temp = base.appendingPathComponent("Temp")
    for dir in [root, external, temp] { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
    let installed = root.appendingPathComponent("Folder/Panel.js")
    try fm.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("ui.show();".utf8).write(to: installed)
    let outside = external.appendingPathComponent("Panel.js")
    try Data("ui.show();".utf8).write(to: outside)
    let encrypted = external.appendingPathComponent("Panel.jsc")
    try Data([0, 1, 2]).write(to: encrypted)
    let fake = FakeCavalryMenu()
    let template = "var request = __CAVALRY_WHEEL_DISPATCH__;"
    let dispatcher = CavalryUIDispatcher(access: fake, scriptsRoot: root, temporaryRoot: temp, template: template, receiptTimeout: 0.05)
    func request(_ url: URL, pid: Int32 = 12345) -> UIDispatchRequest { UIDispatchRequest(version: 1, hostPID: pid, target: url.path) }
    check(scriptsMenuTitle("Scripts") && scriptsMenuTitle("\u{200c}脚本（Scripts）"), "exact English/bilingual Scripts menu titles")
    check(!scriptsMenuTitle("My Scripts") && !scriptsMenuTitle("File"), "unrelated top-level menus are never selected")
    check(scriptMenuComponents(target: installed, root: root) == ["Folder", "Panel"], "nested original menu identity uses basename without extension")
    check(scriptMenuComponents(target: root.appendingPathComponent("Private_assets/Panel.js"), root: root) == nil, "hidden assets folders do not masquerade as installed menu entries")
    check(scriptMenuComponents(target: base.appendingPathComponent("ScriptsOther/Panel.js"), root: root) == nil, "a common root prefix is not membership")
    fake.trusted = false
    check(dispatcher.run(request(outside)).status == "permission-required" && fake.invocations.isEmpty, "missing permission creates no relay or menu action")
    check((try? fm.contentsOfDirectory(atPath: root.path))?.count == 1, "permission failure leaves scripts folder untouched")
    fake.trusted = true; fake.validHost = false
    check(dispatcher.run(request(installed)).status == "error" && fake.invocations.isEmpty, "wrong/dead host never falls back to another Cavalry")
    fake.validHost = true
    check(dispatcher.run(request(encrypted)).status == "unsupported-external-jsc" && fake.invocations.isEmpty, "external encrypted UI is not source-evaluated or plain-loaded")
    check(dispatcher.run(request(installed)).status == "menu-invoked", "installed UI invokes its original menu directly")
    check(fake.invocations.last?.0 == 12345 && fake.invocations.last?.1 == ["Folder", "Panel"], "dispatch retains exact caller PID and path")
    var observedRelay: URL?
    fake.onInvoke = { components in
        let relay = root.appendingPathComponent(components[0] + ".js"); observedRelay = relay
        let text = try String(contentsOf: relay, encoding: .utf8)
        let prefix = "var request = ", suffix = ";"
        let json = String(text.dropFirst(prefix.count).dropLast(suffix.count))
        let payload = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: String]
        check(payload["target"] == outside.path && payload["directory"] == external.path, "relay preserves external source and asset directory including spaces/Unicode")
        try Data("{\"version\":1,\"status\":\"evaluated\"}".utf8).write(to: URL(fileURLWithPath: payload["receipt"]!))
    }
    check(dispatcher.run(request(outside)).status == "evaluated", "external UI requires explicit evaluation receipt")
    check(observedRelay != nil && !fm.fileExists(atPath: observedRelay!.path), "owned relay is removed after confirmed evaluation")
    check((try? fm.contentsOfDirectory(atPath: temp.path))?.isEmpty == true, "receipt is removed after completion")
    fake.onInvoke = { _ in throw MenuDispatchFailure(message: "uncertain final action", executionMayHaveStarted: true) }
    let before = fake.invocations.count
    check(dispatcher.run(request(outside)).status == "completion-unknown" && fake.invocations.count == before + 1, "uncertain execution never retries the menu action")
    check((try? fm.contentsOfDirectory(atPath: root.path)) == ["Folder"], "failed invocation removes only its owned relay")
    fake.onInvoke = nil
    check(dispatcher.run(request(outside)).status == "completion-unknown", "missing UI receipt is not success")
    let unavailableTemplate = CavalryUIDispatcher(access: fake, scriptsRoot: root, temporaryRoot: temp, template: "", receiptTimeout: 0.01)
    let oldCount = fake.invocations.count
    check(unavailableTemplate.run(request(outside)).status == "error" && fake.invocations.count == oldCount, "missing packaged template cannot invoke a blank relay")
    print("PASS: \(checkCount - start) one-shot UI dispatch assertions; fake menu access only.")
}
