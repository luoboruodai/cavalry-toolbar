import AppKit
import ApplicationServices
import Foundation

struct UIDispatchRequest: Decodable {
    let version: Int
    let hostPID: Int32
    let target: String
}
struct UIDispatchResult {
    var status: String
    var message: String
    var target: String = ""
    var dictionary: [String: Any] { ["version": 1, "action": "ui-dispatch", "status": status, "message": message, "target": target] }
}
struct MenuDispatchFailure: Error {
    let message: String
    let executionMayHaveStarted: Bool
}
protocol CavalryMenuAccess {
    var trusted: Bool { get }
    func isCavalry(pid: Int32) -> Bool
    func invoke(pid: Int32, components: [String]) throws
}
func scriptsMenuTitle(_ title: String) -> Bool {
    let invisible = CharacterSet(charactersIn: "\u{200b}\u{200c}\u{200d}\u{2060}\u{feff}")
    let value = title.components(separatedBy: invisible).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    return ["Scripts", "脚本", "脚本（Scripts）", "脚本 (Scripts)"].contains(value)
}
func scriptMenuComponents(target: URL, root: URL) -> [String]? {
    let file = target.resolvingSymlinksInPath().standardizedFileURL.path
    let directory = root.resolvingSymlinksInPath().standardizedFileURL.path
    guard file.hasPrefix(directory + "/") else { return nil }
    var components = String(file.dropFirst(directory.count + 1)).split(separator: "/").map(String.init)
    guard !components.isEmpty, components.count <= 24,
          !components.dropLast().contains(where: { $0.hasSuffix("_assets") || $0.hasPrefix(".") }) else { return nil }
    let leaf = components.removeLast()
    components.append((leaf as NSString).deletingPathExtension)
    return components
}
func uiRelaySource(template: String, target: URL, receipt: URL) throws -> String {
    let marker = "__CAVALRY_WHEEL_DISPATCH__"
    guard template.components(separatedBy: marker).count == 2 else {
        throw MenuDispatchFailure(message: "UI 中继模板未安装或格式无效。", executionMayHaveStarted: false)
    }
    let payload = ["target": target.path, "directory": target.deletingLastPathComponent().path, "receipt": receipt.path]
    let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    let literal = String(decoding: bytes, as: UTF8.self)
        .replacingOccurrences(of: "\u{2028}", with: "\\u2028").replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    return template.replacingOccurrences(of: marker, with: literal)
}
final class MacCavalryMenuAccess: CavalryMenuAccess {
    var trusted: Bool { AXIsProcessTrusted() }
    func isCavalry(pid: Int32) -> Bool {
        guard pid > 0, let app = NSRunningApplication(processIdentifier: pid) else { return false }
        return !app.isTerminated && app.bundleIdentifier == "com.scenegroup.cavalry"
    }
    private func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success ? result : nil
    }
    private func children(_ element: AXUIElement) -> [AXUIElement] {
        (value(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }
    private func title(_ element: AXUIElement) -> String { (value(element, kAXTitleAttribute) as? String) ?? "" }
    private func menuItems(_ element: AXUIElement) -> [AXUIElement] {
        children(element).flatMap { child in
            (value(child, kAXRoleAttribute) as? String) == kAXMenuRole ? children(child) : [child]
        }
    }
    private func only(_ elements: [AXUIElement], matching: (AXUIElement) -> Bool) throws -> AXUIElement? {
        let matches = elements.filter(matching)
        if matches.count > 1 { throw MenuDispatchFailure(message: "菜单项不唯一；未执行脚本。", executionMayHaveStarted: false) }
        return matches.first
    }
    func invoke(pid: Int32, components: [String]) throws {
        guard trusted, isCavalry(pid: pid), let app = NSRunningApplication(processIdentifier: pid), !components.isEmpty else {
            throw MenuDispatchFailure(message: "原 Cavalry 宿主或辅助功能权限已不可用。", executionMayHaveStarted: false)
        }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 1.0)
        let deadline = Date().addingTimeInterval(12)
        guard app.activate(options: []) else {
            throw MenuDispatchFailure(message: "不能激活发起调用的 Cavalry 实例。", executionMayHaveStarted: false)
        }
        guard let barValue = value(application, kAXMenuBarAttribute), CFGetTypeID(barValue) == AXUIElementGetTypeID() else {
            throw MenuDispatchFailure(message: "Cavalry 菜单栏不可用。", executionMayHaveStarted: false)
        }
        let bar = unsafeBitCast(barValue, to: AXUIElement.self)
        guard let scripts = try only(children(bar), matching: { scriptsMenuTitle(self.title($0)) }) else {
            throw MenuDispatchFailure(message: "未找到 Cavalry 的 Scripts 菜单。", executionMayHaveStarted: false)
        }
        // Navigation presses are issued once. Attribute reads may wait for hot-loaded entries.
        guard AXUIElementPerformAction(scripts, kAXPressAction as CFString) == .success else {
            throw MenuDispatchFailure(message: "不能展开 Scripts 菜单；未重试菜单动作。", executionMayHaveStarted: false)
        }
        var parent = scripts
        for (index, component) in components.enumerated() {
            var selected: AXUIElement?
            repeat {
                guard isCavalry(pid: pid), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
                    throw MenuDispatchFailure(message: "Cavalry 已退出或用户切换了应用；已停止分派。", executionMayHaveStarted: false)
                }
                selected = try only(menuItems(parent), matching: { self.title($0) == component })
                if selected == nil { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
            } while selected == nil && Date() < deadline
            guard Date() < deadline, let selected else {
                throw MenuDispatchFailure(message: "没有找到指定的脚本菜单项；未执行脚本。", executionMayHaveStarted: false)
            }
            if let enabled = value(selected, kAXEnabledAttribute) as? Bool, !enabled {
                throw MenuDispatchFailure(message: "指定菜单项被禁用；未执行脚本。", executionMayHaveStarted: false)
            }
            let final = index == components.count - 1
            let result = AXUIElementPerformAction(selected, kAXPressAction as CFString)
            guard result == .success else {
                throw MenuDispatchFailure(message: final ? "菜单执行结果不确定；未自动重复执行。" : "不能展开指定脚本目录。", executionMayHaveStarted: final)
            }
            parent = selected
        }
    }
}
final class CavalryUIDispatcher {
    let access: CavalryMenuAccess
    let scriptsRoot: URL
    let temporaryRoot: URL
    let template: String
    let receiptTimeout: TimeInterval
    init(access: CavalryMenuAccess, scriptsRoot: URL, temporaryRoot: URL = FileManager.default.temporaryDirectory,
         template: String, receiptTimeout: TimeInterval = 12) {
        self.access = access; self.scriptsRoot = scriptsRoot; self.temporaryRoot = temporaryRoot
        self.template = template; self.receiptTimeout = receiptTimeout
    }
    func run(_ request: UIDispatchRequest) -> UIDispatchResult {
        var result = UIDispatchResult(status: "error", message: "UI 分派未完成。", target: request.target)
        var relay: URL?, relayBytes: Data?, receipt: URL?
        defer {
            if let relay, let relayBytes, (try? Data(contentsOf: relay)) == relayBytes { try? FileManager.default.removeItem(at: relay) }
            if let receipt { try? FileManager.default.removeItem(at: receipt) }
        }
        do {
            guard request.version == 1, request.hostPID > 0, request.target.hasPrefix("/") else {
                throw MenuDispatchFailure(message: "UI 分派请求无效。", executionMayHaveStarted: false)
            }
            let target = URL(fileURLWithPath: request.target).resolvingSymlinksInPath().standardizedFileURL
            let ext = target.pathExtension.lowercased()
            let values = try target.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true, ["js", "jsc"].contains(ext) else {
                throw MenuDispatchFailure(message: "所选 UI 脚本已不存在或类型不支持。", executionMayHaveStarted: false)
            }
            guard access.isCavalry(pid: request.hostPID) else {
                throw MenuDispatchFailure(message: "发起调用的 Cavalry 实例已不可用；未选择其他实例代替。", executionMayHaveStarted: false)
            }
            guard access.trusted else {
                return UIDispatchResult(status: "permission-required", message: "请在系统设置 → 隐私与安全性 → 辅助功能，允许 Cavalry Wheel。只在选择 UI 脚本时需要此权限。", target: request.target)
            }
            var components = scriptMenuComponents(target: target, root: scriptsRoot)
            if components == nil {
                guard ext == "js" else {
                    return UIDispatchResult(status: "unsupported-external-jsc", message: "外部加密 UI 脚本不能通过源码中继执行；请将原 .jsc 及资源安装到 Cavalry Scripts，再重新绑定。", target: request.target)
                }
                let id = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                let file = scriptsRoot.appendingPathComponent("CavalryToolbar_UIDispatch_" + id + ".js")
                let response = temporaryRoot.appendingPathComponent("CavalryWheel-UIReceipt-" + id + ".json")
                let source = try uiRelaySource(template: template, target: target, receipt: response)
                let bytes = Data(source.utf8)
                try bytes.write(to: file, options: .withoutOverwriting)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
                relay = file; relayBytes = bytes; receipt = response
                components = [(file.lastPathComponent as NSString).deletingPathExtension]
            }
            try access.invoke(pid: request.hostPID, components: components!)
            if let receipt {
                let deadline = Date().addingTimeInterval(receiptTimeout)
                while !FileManager.default.fileExists(atPath: receipt.path), Date() < deadline {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                }
                guard let data = try? Data(contentsOf: receipt),
                      let response = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], response["version"] as? Int == 1 else {
                    return UIDispatchResult(status: "completion-unknown", message: "菜单已调用，但未收到 UI 源码求值结果；未重试脚本。", target: request.target)
                }
                if response["status"] as? String != "evaluated" {
                    return UIDispatchResult(status: "script-error", message: response["message"] as? String ?? "UI 脚本报告错误，可能已经部分运行。", target: request.target)
                }
                result.status = "evaluated"; result.message = "外部 UI 源码已在 Cavalry UI 引擎求值；请检查实际面板结果。"
            } else {
                result.status = "menu-invoked"; result.message = "已调用原 Cavalry 实例的脚本菜单；请检查实际面板结果。"
            }
        } catch let error as MenuDispatchFailure {
            result.status = error.executionMayHaveStarted ? "completion-unknown" : "error"; result.message = error.message
        } catch { result.message = String(describing: error) }
        return result
    }
}
