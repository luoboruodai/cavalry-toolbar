// AppKit event-model tests only: no events are posted and no host app is opened.
let testApplication = NSApplication.shared
testApplication.setActivationPolicy(.prohibited)
var checkCount = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checkCount += 1
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
func fixture(reduced: Bool = true) -> WheelView {
    let p0 = Profile(name: "工作台", items: [
        Item(slot: 1, name: "普通脚本", mode: "script", available: true),
        Item(slot: 6, name: "面板脚本", mode: "ui", available: true)
    ])
    let p1 = Profile(name: "另一个配置", items: [Item(slot: 10, name: "其他脚本", mode: "script", available: true)])
    return WheelView(request: Request(version: 1, active: 0, reducedMotion: reduced, profiles: [p0, p1], timeoutSeconds: 180))
}
func ringPoint(_ view: WheelView, _ i: Int) -> NSPoint {
    let a = CGFloat.pi / 2 - CGFloat.pi * 2 / CGFloat(view.items.count) * (CGFloat(i) + 0.5)
    return NSPoint(x: view.center.x + cos(a) * 140, y: view.center.y + sin(a) * 140)
}
func mouse(_ kind: NSEvent.EventType, _ point: NSPoint, _ time: TimeInterval) -> NSEvent {
    NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [], timestamp: time,
                      windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
}
func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0,
                    context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!
}
do {
    let v=fixture()
    check(v.index(at:v.center) == -1, "hub is never a run target")
    check(v.index(at:.zero) == -1, "outside is never a run target")
    check(v.index(at:ringPoint(v,0)) == 0, "first radial sector hit")
    check(v.index(at:ringPoint(v,1)) == 1, "second radial sector hit")
    var result:[String:Any]?
    v.onFinish={result=$0}
    v.mouseUp(with:mouse(.leftMouseUp,v.center,v.pointerReadyAt+1))
    check(result == nil, "trailing mouse release without a wheel press is ignored")
    v.mouseDown(with:mouse(.leftMouseDown,v.center,v.pointerReadyAt-0.01))
    v.mouseUp(with:mouse(.leftMouseUp,v.center,v.pointerReadyAt-0.005))
    check(result == nil, "invoking click queued before input-ready time is ignored")
    v.mouseDown(with:mouse(.leftMouseDown,ringPoint(v,0),v.pointerReadyAt+1))
    check(v.pressed == 0, "mouse press has its own feedback state")
    v.mouseUp(with:mouse(.leftMouseUp,ringPoint(v,0),v.pointerReadyAt+1.1))
    check(v.pressed == -1, "mouse release clears pressed feedback before commit")
    check(result?["action"] as? String == "run", "new click commits")
    check(result?["slot"] as? Int == 1, "original configured slot is returned, not visual ordinal")
    v.mouseUp(with:mouse(.leftMouseUp,ringPoint(v,1),v.pointerReadyAt+2))
    check(result?["slot"] as? Int == 1, "duplicate release cannot change a committed result")
}
do {
    let v=fixture();var result:[String:Any]?
    v.onFinish={result=$0}
    v.mouseDown(with:mouse(.leftMouseDown,v.center,v.pointerReadyAt+1))
    v.mouseDragged(with:mouse(.leftMouseDragged,ringPoint(v,1),v.pointerReadyAt+1.1))
    v.mouseUp(with:mouse(.leftMouseUp,ringPoint(v,1),v.pointerReadyAt+1.2))
    check(result?["slot"] as? Int == 6, "hub-to-sector marking gesture commits the chosen slot")
}
do {
    let v=fixture();var result:[String:Any]?
    v.onFinish={result=$0}
    v.mouseDown(with:mouse(.leftMouseDown,v.center,v.pointerReadyAt+1))
    v.mouseUp(with:mouse(.leftMouseUp,v.center,v.pointerReadyAt+1.1))
    check(result?["action"] as? String == "cancel", "fresh hub click cancels")
}
do {
    let v=fixture(reduced:false);var result:[String:Any]?
    v.onFinish={result=$0}
    v.keyDown(with:key(124))
    check(v.selected == 0, "Right selects immediately")
    check(v.motionTimer == nil, "keyboard selection schedules no animation")
    v.keyDown(with:key(125))
    check(v.selected == 1, "Down advances around the wheel")
    v.keyDown(with:key(124))
    check(v.selected == 0, "selection wraps")
    v.keyDown(with:key(123))
    check(v.selected == 1, "reverse selection wraps")
    v.keyDown(with:key(50))
    check(v.profileIndex == 1 && v.selected == -1, "grave accent changes profile and clears stale selection")
    v.keyDown(with:key(50,.shift))
    check(v.profileIndex == 0, "Shift-grave-accent reverses profile selection")
    v.keyDown(with:key(48))
    check(v.profileIndex == 0, "Tab no longer changes profile")
    v.keyDown(with:key(124));v.keyDown(with:key(36))
    check(result?["action"] as? String == "run" && result?["slot"] as? Int == 1, "Return confirms stable slot")
    check(!v.closeAnimated, "keyboard confirmation remains immediate without a close animation")
    let hubView = fixture(); hubView.pick(0)
    check(hubView.hubTitle() == "02" && hubView.hubTitle() != hubView.items[0].name, "hub shows slot state rather than covering the selected script name")
}
do {
    let v=fixture();var result:[String:Any]?
    v.onFinish={result=$0}
    v.settingsButton.performClick(nil)
    check(result?["action"] as? String == "settings", "accessible settings button emits the settings action")
}
do {
    let v=fixture();var result:[String:Any]?
    v.onFinish={result=$0}
    let cg=CGEvent(scrollWheelEvent2Source:nil,units:.line,wheelCount:1,wheel1:-120,wheel2:0,wheel3:0)!
    v.scrollWheel(with:NSEvent(cgEvent:cg)!)
    check(v.selected == 0, "scroll selects a sector")
    check(result == nil, "scroll never executes by itself")
    v.keyDown(with:key(53))
    check(result?["action"] as? String == "cancel", "Escape cancels selected sector")
}
do {
    let v=fixture(reduced:false)
    v.pick(0)
    check(v.motionTimer != nil, "mouse hover animation starts only on demand")
    v.started=ProcessInfo.processInfo.systemUptime-1
    v.advanceMotion()
    check(v.motionTimer == nil && v.highlight[0] == 1, "hover animation reaches exact rest and stops")
    v.pick(1)
    v.finish(["version":1,"action":"cancel"])
    check(v.motionTimer == nil, "closing the wheel invalidates its timer")
}
do {
    let v=fixture(reduced:false)
    v.pick(0); v.press(0)
    check(v.motionTimer != nil, "hover and press share one on-demand timer")
    let now=ProcessInfo.processInfo.systemUptime
    v.started=now-0.08;v.pressStarted=now-0.06;v.advanceMotion()
    check(v.highlight[0] > 0 && v.highlight[0] < 1, "hover exposes an intermediate frame")
    check(v.pressHighlight[0] > 0 && v.pressHighlight[0] < 1, "press exposes an intermediate frame")
    v.started=ProcessInfo.processInfo.systemUptime-1;v.pressStarted=ProcessInfo.processInfo.systemUptime-1;v.advanceMotion()
    check(v.highlight[0] == 1 && v.pressHighlight[0] == 1, "hover and press land on exact targets")
    check(v.motionTimer == nil, "timer stops when both channels finish")
    v.press(-1)
    check(v.motionTimer != nil, "release starts a bounded return transition")
    v.pressStarted=ProcessInfo.processInfo.systemUptime-1;v.advanceMotion()
    check(v.pressHighlight[0] == 0 && v.motionTimer == nil, "release reaches exact rest and stops")
    v.pick(0);v.press(0);v.keyDown(with:key(124))
    check(v.motionTimer == nil, "keyboard input retakes control without an animated transition")
}
do {
    let v=fixture(reduced:true)
    v.pick(0);v.press(0)
    check(v.motionTimer == nil && v.pressHighlight[0] == 1, "reduced motion keeps instant pressed color state without a timer")
    v.press(-1)
    check(v.pressHighlight[0] == 0 && v.motionTimer == nil, "reduced motion release is also immediate")
}
do {
    let v=fixture(reduced:false);var result:[String:Any]?
    v.onFinish={result=$0}
    v.pick(0);v.execute(animated:true)
    check(result?["action"] as? String == "run", "pointer selection returns its response synchronously before the visual close")
    check(v.closeAnimated, "pointer selection opts into the Filee-inspired close")
    let profile=v.profileIndex;v.keyDown(with:key(50))
    check(v.profileIndex == profile, "finished wheel ignores keyboard profile changes during close")
}
do {
    let entries = (0..<12).map { Item(slot: $0, name: "close-\($0)", mode: "script", available: true) }
    let v=WheelView(request: Request(version: 1, active: 0, reducedMotion: false,
        profiles: [Profile(name: "close", items: entries)], timeoutSeconds: 180))
    var completed=false
    v.playCloseAnimation { completed=true }
    check(v.closeTimer != nil && v.closeValues.count == 12, "close starts one bounded timer for all slices")
    check(v.closeValues.allSatisfy { $0 == 1 }, "close starts from the current fully open ring")
    v.closeStarted=ProcessInfo.processInfo.systemUptime-0.08;v.advanceClose()
    check(v.closeValues[0] > 0 && v.closeValues[0] < 1, "first slice has a shrinking/fading intermediate frame")
    check(v.closeValues[11] == 1, "10ms per-index stagger delays the twelfth slice")
    check(!completed, "close callback waits for every slice")
    check(abs(v.closeDuration + 11 * v.closeStagger - 0.27) < 0.000001, "12-slice close budget is 270ms")
    v.closeStarted=ProcessInfo.processInfo.systemUptime-0.28;v.advanceClose()
    check(v.closeValues.allSatisfy { $0 == 0 }, "close snaps every slice to exact zero after the final stagger")
    check(v.closeTimer == nil && !v.closing && completed, "close stops its timer and invokes completion exactly at rest")
}
do {
    let v=fixture(reduced:true);var completed=false
    v.pick(0);v.execute(animated:true)
    check(!v.closeAnimated, "reduced motion keeps pointer close immediate")
    v.playCloseAnimation { completed=true }
    check(completed && v.closeTimer == nil, "reduced motion close completion is synchronous with no timer")
}
do {
    for count in [1, 2, 6, 12] {
        let entries = (0..<count).map { Item(slot: $0, name: "a-very-long-script-name-for-sector-layout", mode: "script", available: true) }
        let v = WheelView(request: Request(version: 1, active: 0, reducedMotion: true,
            profiles: [Profile(name: "layout", items: entries)], timeoutSeconds: 180))
        for i in entries.indices {
            let layout = v.arcLabelLayout(index: i, count: count)
            check(layout.metaRadius > v.inner && layout.metaRadius < v.outer, "metadata arc stays inside ring for count \(count)")
            check(layout.nameRadii.allSatisfy { $0 > layout.metaRadius && $0 < v.outer }, "name arcs stay separated from metadata and outer edge for count \(count)")
            check(layout.maxNameWidth > 0, "arc has a positive text budget for count \(count)")
            let font = NSFont.systemFont(ofSize: layout.nameFont, weight: .medium)
            let lines = v.nameLines(entries[i].name, font: font, maxWidth: layout.maxNameWidth, maxLines: 2)
            check(lines.count <= (count >= 10 ? 4 : 2), "arc name wrapping respects the dense-track budget for count \(count)")
            for line in lines {
                check((line as NSString).size(withAttributes: [.font: font]).width <= layout.maxNameWidth * 1.05,
                      "each arc line fits its angular budget for count \(count)")
            }
        }
    }
}
print("PASS: \(checkCount) native AppKit event-model assertions; no host/window interaction.")
