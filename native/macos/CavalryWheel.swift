import AppKit
import ApplicationServices
import Foundation

// One-shot local selection or explicitly requested UI menu dispatch; no network or keyboard hooks.
struct Item: Decodable {
    let slot: Int
    let name: String
    let mode: String
    let available: Bool
}
struct Profile: Decodable { let name: String; let items: [Item] }
struct Request: Decodable {
    let version: Int
    let active: Int
    let reducedMotion: Bool
    let profiles: [Profile]
    let timeoutSeconds: Double?
    var accent: String? = nil
    var accentText: String? = nil
}
final class WheelPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func themeColor(_ value: String?, fallback: UInt32, alpha: CGFloat = 1) -> NSColor {
    guard let value, let number = UInt32(value.replacingOccurrences(of: "#", with: ""), radix: 16), value.count <= 9 else { return color(fallback, alpha) }
    return color(number, alpha)
}
func blend(_ from: NSColor, _ to: NSColor, _ amount: CGFloat) -> NSColor {
    let t = min(1, max(0, amount))
    return from.blended(withFraction: t, of: to) ?? (t >= 1 ? to : from)
}
func easeOut(_ progress: CGFloat) -> CGFloat {
    if progress <= 0 || progress >= 1 { return progress }
    var low: CGFloat = 0, high: CGFloat = 1, t: CGFloat = 0
    for _ in 0..<14 {
        t = (low + high) / 2
        let u = 1 - t
        let x = 3 * u * u * t * 0.23 + 3 * u * t * t * 0.32 + t * t * t
        if x < progress { low = t } else { high = t }
    }
    return 1 - pow(1 - t, 3)
}
final class WheelView: NSView {
    let request: Request
    var profileIndex: Int
    var selected = -1
    var tracking: NSTrackingArea?
    var highlight: [CGFloat] = []
    var from: [CGFloat] = []
    var pressHighlight: [CGFloat] = []
    var pressFrom: [CGFloat] = []
    var started: TimeInterval = 0
    var pressStarted: TimeInterval = 0
    var motionTimer: Timer?
    var closeTimer: Timer?
    var closeValues: [CGFloat] = []
    var closeStarted: TimeInterval = 0
    var closeCompletion: (() -> Void)?
    var closing = false
    var closeAnimated = false
    var scrollRemainder: CGFloat = 0
    var finished = false
    var ready = false
    var hasMousePress = false
    var pressed = -1
    let pointerReadyAt = ProcessInfo.processInfo.systemUptime + 0.15
    let hoverDuration: TimeInterval = 0.16
    let pressDuration: TimeInterval = 0.12
    let radialMotion: CGFloat = 6
    let closeDuration: TimeInterval = 0.16
    let closeStagger: TimeInterval = 0.01
    var onFinish: (([String: Any]) -> Void)?
    var settingsButton: NSButton!
    let center = NSPoint(x: 220, y: 249)
    let outer: CGFloat = 194
    let inner: CGFloat = 90
    var profile: Profile { request.profiles[profileIndex] }
    var items: [Item] { profile.items }

    init(request: Request) {
        self.request = request
        profileIndex = min(max(request.active, 0), request.profiles.count - 1)
        super.init(frame: NSRect(x: 0, y: 0, width: 440, height: 496))
        resetProfile()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Cavalry 脚本轮盘")
        setAccessibilityHelp("滚轮或方向键选择，回车运行，Escape 取消，` 切换配置。")
        // The settings affordance is custom-drawn like the rest of the wheel, but
        // it remains a real accessible button for keyboard and assistive clients.
        settingsButton = NSButton(title: "打开配置", target: self, action: #selector(openSettings))
        settingsButton.isBordered = false
        settingsButton.bezelStyle = .inline
        settingsButton.isTransparent = true
        settingsButton.focusRingType = .none
        settingsButton.font = NSFont.systemFont(ofSize: 10)
        settingsButton.contentTintColor = themeColor(request.accentText, fallback: 0x2fcd71)
        settingsButton.frame = NSRect(x: 75, y: 4, width: 290, height: 16)
        settingsButton.setAccessibilityLabel("打开配置")
        addSubview(settingsButton)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { true }
    override var isOpaque: Bool { false }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
        super.updateTrackingAreas()
    }
    func resetProfile() {
        motionTimer?.invalidate(); motionTimer = nil
        closeTimer?.invalidate(); closeTimer = nil; closeCompletion = nil; closing = false; closeValues = []
        highlight = Array(repeating: 0, count: items.count)
        from = highlight; pressHighlight = highlight; pressFrom = highlight
        selected = -1; pressed = -1; scrollRemainder = 0
        needsDisplay = true
    }
    func snapMotion() {
        motionTimer?.invalidate(); motionTimer = nil
        highlight = items.indices.map { $0 == selected ? 1 : 0 }
        pressHighlight = items.indices.map { $0 == pressed ? 1 : 0 }
        needsDisplay = true
    }
    func startMotion() {
        if motionTimer == nil {
            motionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.advanceMotion() }
            RunLoop.main.add(motionTimer!, forMode: .common)
        }
        needsDisplay = true
    }
    func pick(_ index: Int, animated: Bool = true) {
        guard !finished, index != selected else { return }
        if motionTimer != nil { advanceMotion() }
        selected = index
        setAccessibilityValue(index >= 0 ? items[index].name : profile.name)
        if request.reducedMotion || !animated { snapMotion(); return }
        from = highlight; started = ProcessInfo.processInfo.systemUptime
        startMotion()
    }
    func press(_ index: Int) {
        guard !finished, index != pressed else { return }
        if motionTimer != nil { advanceMotion() }
        pressed = index
        if request.reducedMotion { snapMotion(); return }
        pressFrom = pressHighlight; pressStarted = ProcessInfo.processInfo.systemUptime
        startMotion()
    }
    func advanceMotion() {
        let now = ProcessInfo.processInfo.systemUptime
        let hoverProgress = min(1, max(0, (now - started) / hoverDuration))
        let pressProgress = min(1, max(0, (now - pressStarted) / pressDuration))
        let hoverEased = easeOut(hoverProgress), pressEased = easeOut(pressProgress)
        for i in items.indices {
            highlight[i] = from[i] + ((i == selected ? 1 : 0) - from[i]) * hoverEased
            pressHighlight[i] = pressFrom[i] + ((i == pressed ? 1 : 0) - pressFrom[i]) * pressEased
        }
        needsDisplay = true
        if hoverProgress >= 1 && pressProgress >= 1 { snapMotion() }
    }
    func index(at point: NSPoint) -> Int {
        let dx = point.x - center.x, dy = point.y - center.y
        let radius = hypot(dx, dy)
        guard radius >= inner, radius <= outer + 7, !items.isEmpty else { return -1 }
        let angle = (CGFloat.pi / 2 - atan2(dy, dx) + CGFloat.pi * 2).truncatingRemainder(dividingBy: CGFloat.pi * 2)
        return min(items.count - 1, Int(angle / (CGFloat.pi * 2 / CGFloat(items.count))))
    }
    @objc func openSettings() {
        let eventType = NSApplication.shared.currentEvent?.type
        finish(["version": 1, "action": "settings"], animated: eventType == .leftMouseDown || eventType == .leftMouseUp)
    }
    func finish(_ response: [String: Any], animated: Bool = false) {
        guard !finished else { return }
        finished = true
        closeAnimated = animated && !request.reducedMotion && !items.isEmpty
        motionTimer?.invalidate(); motionTimer = nil
        closeTimer?.invalidate(); closeTimer = nil
        onFinish?(response)
    }
    func execute(animated: Bool = false) {
        guard selected >= 0, selected < items.count, items[selected].available else { NSSound.beep(); return }
        finish(["version": 1, "action": "run", "profile": profileIndex, "slot": items[selected].slot], animated: animated)
    }
    func playCloseAnimation(completion: @escaping () -> Void) {
        guard !request.reducedMotion && !items.isEmpty else { completion(); return }
        motionTimer?.invalidate(); motionTimer = nil
        closeTimer?.invalidate(); closeTimer = nil
        closeValues = Array(repeating: 1, count: items.count)
        closeStarted = ProcessInfo.processInfo.systemUptime
        closeCompletion = completion; closing = true
        closeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.advanceClose() }
        RunLoop.main.add(closeTimer!, forMode: .common)
        needsDisplay = true
    }
    func advanceClose() {
        let elapsed = ProcessInfo.processInfo.systemUptime - closeStarted
        var done = true
        for i in items.indices {
            let t = min(1, max(0, (elapsed - Double(i) * closeStagger) / closeDuration))
            closeValues[i] = 1 - easeOut(t)
            done = done && t >= 1
        }
        needsDisplay = true
        if done {
            closeValues = Array(repeating: 0, count: items.count); needsDisplay = true
            closeTimer?.invalidate(); closeTimer = nil; closing = false
            let completion = closeCompletion; closeCompletion = nil
            completion?()
        }
    }
    override func mouseMoved(with event: NSEvent) { pick(index(at: convert(event.locationInWindow, from: nil))) }
    override func mouseExited(with event: NSEvent) { pick(-1); press(-1) }
    override func mouseDown(with event: NSEvent) {
        // Discard the launch gesture still queued in the host/window server. Hover and all
        // keyboard navigation work immediately; only committing this trailing click is gated.
        guard event.timestamp >= pointerReadyAt else { return }
        hasMousePress = true
        let point = convert(event.locationInWindow, from: nil)
        if hypot(point.x - center.x, point.y - center.y) < inner { return }
        let hit = index(at: point)
        pick(hit); press(hit)
    }
    override func mouseDragged(with event: NSEvent) {
        let hit = index(at: convert(event.locationInWindow, from: nil))
        pick(hit); press(hit)
    }
    override func mouseUp(with event: NSEvent) {
        // A popup opened from a button can receive the invoking button's trailing release.
        // Only a press that began in this wheel can commit or cancel it.
        guard hasMousePress, event.timestamp >= pointerReadyAt else { return }
        hasMousePress = false
        press(-1)
        let point = convert(event.locationInWindow, from: nil)
        if point.y < 42 { finish(["version":1, "action":"settings"], animated: true); return }
        let hit = index(at: point)
        if hit < 0 { finish(["version":1, "action":"cancel","reason":"center-or-outside"], animated: true); return }
        pick(hit); execute(animated: true)
    }
    override func rightMouseDown(with event: NSEvent) { finish(["version":1, "action":"cancel"], animated: true) }
    func step(_ delta: Int) {
        guard !items.isEmpty else { return }
        let n = items.count
        pick(selected < 0 ? (delta > 0 ? 0 : n - 1) : (selected + delta + n) % n, animated: false)
    }
    override func scrollWheel(with event: NSEvent) {
        let delta = abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) ? event.scrollingDeltaY : event.scrollingDeltaX
        scrollRemainder += event.hasPreciseScrollingDeltas ? delta / 12 : delta
        guard abs(scrollRemainder) >= 1 else { return }
        let direction = scrollRemainder < 0 ? 1 : -1
        scrollRemainder = 0
        step(direction)
    }
    override func keyDown(with event: NSEvent) {
        guard !finished else { return }
        switch event.keyCode {
        case 53: finish(["version":1, "action":"cancel"])
        case 36, 76: execute()
        case 123, 126: step(-1)
        case 124, 125: step(1)
        case 50: // grave accent (`), with Shift for reverse traversal
            profileIndex = (profileIndex + (event.modifierFlags.contains(.shift) ? request.profiles.count - 1 : 1)) % request.profiles.count
            resetProfile()
        default: break
        }
    }
    struct ArcLabelLayout {
        let middle: CGFloat
        let angleStep: CGFloat
        let metaRadius: CGFloat
        let nameRadii: [CGFloat]
        let maxNameWidth: CGFloat
        let slotFont: CGFloat
        let nameFont: CGFloat
    }
    func arcLabelLayout(index: Int, count: Int) -> ArcLabelLayout {
        let n = max(1, count), step = CGFloat.pi * 2 / CGFloat(n)
        let middle = CGFloat.pi / 2 - step * (CGFloat(index) + 0.5)
        // Separate concentric tracks keep metadata and names on the arc itself.
        // The outer track never reaches the wheel edge; dense profiles get two.
        return ArcLabelLayout(middle: middle, angleStep: step,
                              metaRadius: n >= 10 ? inner + 12 : inner + 20,
                              nameRadii: n >= 10 ? [outer - 76, outer - 62, outer - 48, outer - 34] : [outer - 66, outer - 46, outer - 27],
                              maxNameWidth: (outer - 27) * max(0.1, step - 0.06),
                              slotFont: n >= 10 ? 9 : 10,
                              nameFont: n >= 10 ? 9 : n >= 5 ? 11 : 12)
    }
    func hubTitle() -> String {
        selected >= 0 ? String(format: "%02d", items[selected].slot + 1) : profile.name
    }
    func nameLines(_ text: String, font: NSFont, maxWidth: CGFloat, maxLines: Int) -> [String] {
        let characters = Array(text)
        if characters.isEmpty { return [""] }
        var lines: [String] = [], start = 0
        while start < characters.count && lines.count < maxLines {
            var end = start, lastBreak: Int? = nil, overflow = false
            while end < characters.count {
                let candidate = String(characters[start...end])
                let width = (candidate as NSString).size(withAttributes: [.font: font]).width
                if width > maxWidth && end > start {
                    let split = lastBreak != nil && lastBreak! > start ? lastBreak! : end
                    lines.append(String(characters[start..<split]))
                    start = split; overflow = true; break
                }
                end += 1
                if end > start, characters[end - 1] == "-" || characters[end - 1] == "_" || characters[end - 1] == " " {
                    lastBreak = end
                }
            }
            if !overflow {
                if end > start { lines.append(String(characters[start..<end])); start = end }
                else { lines.append(String(characters[start])); start += 1 }
            }
        }
        if start < characters.count, !lines.isEmpty {
            var last = lines.removeLast()
            while !last.isEmpty && ((last + "…") as NSString).size(withAttributes: [.font: font]).width > maxWidth {
                last.removeLast()
            }
            lines.append(last + "…")
        }
        return lines
    }
    func arcText(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular,
                 tint: NSColor, origin: NSPoint, radius: CGFloat, middle: CGFloat, maxWidth: CGFloat) {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: tint]
        let characters = Array(text)
        if characters.isEmpty || radius <= 0 || maxWidth <= 0 { return }
        let widths = characters.map { String($0).size(withAttributes: attributes).width }
        let rawTotal = widths.reduce(0, +)
        let fit = min(1, maxWidth / max(rawTotal, 0.001))
        let total = rawTotal * fit
        let direction: CGFloat = sin(middle) >= 0 ? -1 : 1
        let start = direction < 0 ? middle + total / (2 * radius) : middle - total / (2 * radius)
        var travelled: CGFloat = 0
        for (index, character) in characters.enumerated() {
            let width = widths[index] * fit
            let theta = start + direction * (travelled + width / 2) / radius
            let point = NSPoint(x: origin.x + cos(theta) * radius, y: origin.y + sin(theta) * radius)
            let rotation = direction < 0 ? theta - CGFloat.pi / 2 : theta + CGFloat.pi / 2
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: point.x, yBy: point.y)
            transform.rotate(byRadians: rotation)
            if fit < 1 { transform.scale(by: fit) }
            transform.concat()
            let glyph = String(character) as NSString
            let glyphWidth = widths[index]
            glyph.draw(with: NSRect(x: -glyphWidth / 2, y: -size * 0.65, width: max(1, glyphWidth), height: size * 1.3),
                       options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
            travelled += width
        }
    }
    func label(_ string: String, size: CGFloat, weight: NSFont.Weight = .regular, tint: NSColor, rect: NSRect, lines: Bool = false) {
        let style = NSMutableParagraphStyle(); style.alignment = .center
        style.lineBreakMode = lines ? .byWordWrapping : .byTruncatingTail
        let attributes: [NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize: size, weight:weight), .foregroundColor:tint, .paragraphStyle:style]
        (string as NSString).draw(with: rect, options:[.usesLineFragmentOrigin, .usesFontLeading], attributes:attributes)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill(using: .copy)
        let count = max(1, items.count)
        let angleStep = CGFloat.pi * 2 / CGFloat(count)
        for i in 0..<count {
            let middle = CGFloat.pi / 2 - angleStep * (CGFloat(i) + 0.5)
            let amount = i < highlight.count ? highlight[i] : 0
            let pressure = i < pressHighlight.count ? pressHighlight[i] : 0
            let offset: CGFloat = request.reducedMotion ? 0 : radialMotion * (amount - pressure)
            let open = i < closeValues.count ? closeValues[i] : 1
            if open <= 0.001 { continue }
            let closeScale = 0.55 + 0.45 * open
            let closeRotation = (1 - min(open, 1)) * -0.35
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(open)
            let transform = NSAffineTransform()
            transform.translateX(by: center.x + cos(middle) * offset, yBy: center.y + sin(middle) * offset)
            transform.rotate(byRadians: closeRotation)
            transform.scale(by: closeScale)
            transform.translateX(by: -center.x, yBy: -center.y)
            transform.concat()
            let gap: CGFloat = 0.010
            let start = CGFloat.pi / 2 - angleStep*CGFloat(i) - gap
            let end = CGFloat.pi / 2 - angleStep*CGFloat(i+1) + gap
            let path=NSBezierPath()
            path.appendArc(withCenter:center,radius:outer,startAngle:start*180/CGFloat.pi,endAngle:end*180/CGFloat.pi,clockwise:true)
            path.line(to:NSPoint(x:center.x+cos(end)*inner,y:center.y+sin(end)*inner))
            path.appendArc(withCenter:center,radius:inner,startAngle:end*180/CGFloat.pi,endAngle:start*180/CGFloat.pi,clockwise:false)
            path.close()
            let available = i < items.count && items[i].available
            let restFill = color(0x262b34,0.98)
            let hoverFill = available ? themeColor(request.accent, fallback: 0x078430) : color(0x183022)
            blend(blend(restFill, hoverFill, amount), color(0x15181e), pressure * 0.25).setFill()
            path.fill()
            blend(color(0x3b424d, 0.72), themeColor(request.accentText, fallback: 0x2fcd71), amount).setStroke();path.lineWidth=1;path.stroke()
            if i < items.count {
                let layout = arcLabelLayout(index: i, count: count)
                let meta = String(format: "%02d", items[i].slot + 1) + " · " + items[i].mode.uppercased()
                arcText(meta, size: layout.slotFont, tint: blend(color(0xaab3bf), .white, amount), origin: center,
                        radius: layout.metaRadius, middle: layout.middle,
                        maxWidth: layout.metaRadius * max(0.1, layout.angleStep - 0.06))
                let font = NSFont.systemFont(ofSize: layout.nameFont, weight: .medium)
                let lines = nameLines(items[i].name, font: font, maxWidth: layout.maxNameWidth, maxLines: count >= 10 ? 4 : 2)
                let radii = lines.count == 1 ? [outer - 32] : Array(layout.nameRadii.suffix(lines.count))
                for (lineIndex, line) in lines.enumerated() {
                    arcText(line, size: layout.nameFont, weight: .medium,
                            tint: available ? color(0xf0f2f3) : color(0xdab445), origin: center,
                            radius: radii[lineIndex], middle: layout.middle, maxWidth: radii[lineIndex] * max(0.1, layout.angleStep - 0.06))
                }
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        color(0x1d2129,0.98).setFill()
        NSBezierPath(ovalIn:NSRect(x:center.x-inner+5,y:center.y-inner+5,width:(inner-5)*2,height:(inner-5)*2)).fill()
        // The selected script is already named inside its sector. The hub carries
        // only slot/profile state so a long selected name cannot cover its neighbors.
        label(hubTitle(),size:selected>=0 ? 20 : 15,weight:.semibold,tint:color(0xf0f2f3),rect:NSRect(x:center.x-70,y:center.y+2,width:140,height:34),lines:true)
        label(selected>=0 ? (items[selected].available ? "点击 / 回车运行" : "文件失效，请重新绑定") : items.isEmpty ? "先在配置页添加脚本" : "\(items.count) 个脚本",size:11,tint:themeColor(request.accentText, fallback: 0x2fcd71),rect:NSRect(x:center.x-78,y:center.y-23,width:156,height:20))
        label("中心 / Esc 取消",size:10,tint:color(0xaab3bf),rect:NSRect(x:center.x-70,y:center.y-47,width:140,height:18))
        let caption=NSBezierPath(roundedRect:NSRect(x:75,y:0,width:290,height:42),xRadius:12,yRadius:12)
        color(0x15181e,0.97).setFill();caption.fill()
        label("滚轮 / 方向键选择 · ` 切换配置",size:11,tint:color(0xaab3bf),rect:NSRect(x:75,y:20,width:290,height:17))
        label("打开配置",size:10,tint:themeColor(request.accentText, fallback: 0x2fcd71),rect:NSRect(x:75,y:4,width:290,height:16))
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel:WheelPanel!
    var view:WheelView!
    var activated=false
    var responded=false
    var responseFile:String?
    var lifetimeTimer:Timer?
    var outsideClickMonitor:Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            if (CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3), CommandLine.arguments[1] == "--accessibility-status" {
                // Optional response file preserves the real LaunchServices result for support;
                // it never prompts, grants, or bypasses accessibility permission.
                responseFile = CommandLine.arguments.count == 3 ? CommandLine.arguments[2] : nil
                finish(["version": 1, "action": "accessibility-status", "trusted": AXIsProcessTrusted()]); return
            }
            if (CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4), CommandLine.arguments[1] == "--dispatch-ui" {
                responseFile = CommandLine.arguments.count == 4 ? CommandLine.arguments[3] : nil
                let input = URL(fileURLWithPath: CommandLine.arguments[2])
                let data = try Data(contentsOf: input)
                guard data.count < 65536 else { throw NSError(domain:"Wheel",code:4,userInfo:[NSLocalizedDescriptionKey:"UI dispatch request too large"])}
                let request = try JSONDecoder().decode(UIDispatchRequest.self, from: data)
                let temp = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL
                if input.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == temp,
                   input.lastPathComponent.hasPrefix("CavalryWheel-"), input.lastPathComponent.hasSuffix("-ui.json") {
                    try? FileManager.default.removeItem(at: input)
                }
                let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Cavalry/Scripts")
                let templateURL = Bundle.main.url(forResource: "UIRelay", withExtension: "js")
                let template = templateURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
                let dispatcher = CavalryUIDispatcher(access: MacCavalryMenuAccess(), scriptsRoot: root, template: template)
                DispatchQueue.main.async { [weak self] in
                    let result = dispatcher.run(request)
                    if result.status == "permission-required" {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        _ = AXIsProcessTrustedWithOptions(options)
                    } else if !["evaluated", "menu-invoked"].contains(result.status) {
                        let alert = NSAlert(); alert.messageText = "Cavalry Wheel · UI 分派"; alert.informativeText = result.message
                        alert.addButton(withTitle: "好"); alert.runModal()
                    }
                    self?.finish(result.dictionary)
                }
                return
            }
            guard CommandLine.arguments.count==2 || CommandLine.arguments.count==3 else { throw NSError(domain:"Wheel",code:1,userInfo:[NSLocalizedDescriptionKey:"Expected a request JSON file"])}
            responseFile = CommandLine.arguments.count == 3 ? CommandLine.arguments[2] : nil
            let data=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
            guard data.count<262144 else { throw NSError(domain:"Wheel",code:2,userInfo:[NSLocalizedDescriptionKey:"Request too large"])}
            let request=try JSONDecoder().decode(Request.self,from:data)
            guard request.version==1, !request.profiles.isEmpty, request.profiles.count<=20,
                  request.profiles.allSatisfy({$0.items.count<=12 && $0.items.allSatisfy({$0.slot>=0 && $0.slot<12 && ["script","ui"].contains($0.mode)})}) else {
                throw NSError(domain:"Wheel",code:3,userInfo:[NSLocalizedDescriptionKey:"Invalid wheel request"])
            }
            view=WheelView(request:request)
            view.onFinish={ [weak self] response in self?.finish(response) }
            panel=WheelPanel(contentRect:view.bounds,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            panel.title="Cavalry Wheel · 脚本轮盘";panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false
            panel.level = .floating;panel.hidesOnDeactivate=false;panel.isReleasedWhenClosed=false
            panel.isFloatingPanel=true;panel.worksWhenModal=true;panel.becomesKeyOnlyIfNeeded=false
            panel.collectionBehavior=[.moveToActiveSpace,.fullScreenAuxiliary]
            panel.contentView=view;panel.acceptsMouseMovedEvents=true;panel.delegate=self
            let mouse=NSEvent.mouseLocation
            let screen=NSScreen.screens.first(where:{$0.frame.contains(mouse)}) ?? NSScreen.main!
            let visible=screen.visibleFrame
            let x=min(max(mouse.x-view.center.x,visible.minX),visible.maxX-view.bounds.width)
            let y=min(max(mouse.y-view.center.y,visible.minY),visible.maxY-view.bounds.height)
            panel.setFrameOrigin(NSPoint(x:x,y:y))
            panel.makeKeyAndOrderFront(nil);panel.makeFirstResponder(view)
            view.ready=true
            // A nonactivating popup can coexist with a host's modal Script UI. Focus changes
            // during the invoking callback aren't cancellation; an actual new outside click is.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]) { [weak self] _ in
                guard let self, !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
                self.finish(["version":1,"action":"cancel","reason":"outside-click"], animated: true)
            }
            lifetimeTimer = Timer.scheduledTimer(withTimeInterval:min(180,max(15,request.timeoutSeconds ?? 180)), repeats:false) { [weak self] _ in
                self?.finish(["version":1,"action":"cancel","reason":"timeout"])
            }
        } catch { finish(["version":1,"action":"error","message":String(describing:error)]) }
    }
    func finish(_ response:[String:Any], animated:Bool = false) {
        guard !responded else{return};responded=true
        let animateClose = view != nil && !view.items.isEmpty && !view.request.reducedMotion && (animated || view.closeAnimated)
        view?.motionTimer?.invalidate();view?.motionTimer=nil;lifetimeTimer?.invalidate()
        if !animateClose { view?.closeTimer?.invalidate();view?.closeTimer=nil }
        if let monitor=outsideClickMonitor { NSEvent.removeMonitor(monitor);outsideClickMonitor=nil }
        if animateClose { panel?.ignoresMouseEvents = true }
        // Return the selection first: Cavalry can start the script while the visual close runs.
        if let bytes=try? JSONSerialization.data(withJSONObject:response,options:[.sortedKeys]),let text=String(data:bytes,encoding:.utf8){
            let output = (text+"\n").data(using:.utf8)!
            if let responseFile {
                do { try output.write(to:URL(fileURLWithPath:responseFile),options:.atomic) }
                catch { FileHandle.standardError.write(("Wheel response write failed: \(error)\n").data(using:.utf8)!) }
            } else { FileHandle.standardOutput.write(output) }
        }
        if animateClose {
            view?.playCloseAnimation { [weak self] in self?.completeClose() }
        } else { completeClose() }
    }
    func completeClose() {
        panel?.orderOut(nil)
        NSApplication.shared.terminate(nil)
    }

}
let app=NSApplication.shared
let delegate=AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate=delegate
app.run()
