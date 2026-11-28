// Binsen
// 把 iPhone 快捷指令发来的文字变成 Mac 自带「便笺」里的一张新便笺。两条通道：
//   · 提醒事项（推荐）：快捷指令「添加新提醒事项」到「Binsen」列表，几秒就同步到 Mac
//   · iCloud 云盘文件：快捷指令「存储文件」到 iCloud 云盘/快捷指令/Binsen（iPhone 可能要等打开「文件」App 才上传）
//
// 用法：
//   Binsen                  常驻运行（由 LaunchAgent 启动）
//   Binsen --test [文字]     立即新建一张便笺，用来自检
//   Binsen --remind [文字]   往「Binsen」提醒事项列表里加一条，用来自检提醒事项通道
//   Binsen --version

import AppKit
import ApplicationServices
import CoreServices
import EventKit
import Foundation

let appVersion = "0.7.0"
let bundleID = "io.github.qinov5.binsen"
let stickiesBundleID = "com.apple.Stickies"
let archiveFolderName = "已处理"
let acceptedExtensions: Set<String> = ["", "txt", "text", "md", "markdown"]

let home = FileManager.default.homeDirectoryForCurrentUser
let settings = UserDefaults.standard
let launchedAt = Date()

// 读到 iCloud 里还没下载到本机的文件时，让系统当场下载，而不是直接报错（后台进程默认不一定会下载）。
// 3 = IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES，0 = IOPOL_SCOPE_PROCESS，2 = IOPOL_MATERIALIZE_DATALESS_FILES_ON
// 下载期间，读文件的线程会一直等，所以读文件统一放在后台线程，主线程不等 iCloud。
let materializeResult = setiopolicy_np(3, 0, 2)

/// 默认收件箱：iCloud 云盘 /快捷指令/Binsen
/// 可改：defaults write io.github.qinov5.binsen InboxPath "~/某个文件夹"
var inboxURL: URL {
    if let custom = settings.string(forKey: "InboxPath"), !custom.isEmpty {
        return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
    }
    return home.appendingPathComponent(
        "Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/Binsen",
        isDirectory: true)
}

/// 新建便笺后把键盘焦点还给原来的 App，避免正在打字时字被敲进便笺。
/// 关闭：defaults write io.github.qinov5.binsen RestoreFocus -bool false
var restoreFocus: Bool { settings.object(forKey: "RestoreFocus") as? Bool ?? true }

/// 提醒事项通道监听的列表名（没有会自动新建）。
/// 可改：defaults write io.github.qinov5.binsen RemindersList "某个列表"
/// 关闭：defaults write io.github.qinov5.binsen UseReminders -bool false
var remindersListName: String {
    let name = settings.string(forKey: "RemindersList")?.trimmingCharacters(in: .whitespaces) ?? ""
    return name.isEmpty ? "Binsen" : name
}
var useReminders: Bool { settings.object(forKey: "UseReminders") as? Bool ?? true }

/// 新便笺放在哪儿：topRight（默认）从屏幕右上角往下排，不压住已有便笺；cascade 从便笺默认位置依次往右下错开；off 不挪
/// 改：defaults write io.github.qinov5.binsen NotePlacement cascade
var notePlacement: String { (settings.string(forKey: "NotePlacement") ?? "").lowercased() }

/// 已处理的原文保留几天，到期自动删除（iCloud 云盘「已处理」里的文件、提醒事项列表里已完成的条目）；0 = 一直保留
/// 改：defaults write io.github.qinov5.binsen KeepDays -int 7
var keepDays: Int { settings.object(forKey: "KeepDays") == nil ? 30 : max(0, settings.integer(forKey: "KeepDays")) }

// MARK: - 日志  ~/Library/Logs/Binsen.log

let logURL = home.appendingPathComponent("Library/Logs/Binsen.log")
let logDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()
let clockFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MM-dd HH:mm:ss"
    return f
}()

func logLine(_ message: String) {
    let line = "\(logDateFormatter.string(from: Date())) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    FileHandle.standardError.write(data)
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: logURL)
    }
}

func describe(_ error: Error) -> String {
    let ns = error as NSError
    var parts = ["\(ns.domain) \(ns.code)"]
    if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
        parts.append("\(underlying.domain) \(underlying.code)")
    }
    return parts.joined(separator: " / ")
}

func trimLogIfNeeded() {
    let size = (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size] as? Int) ?? 0
    if size > 1_000_000 { try? Data().write(to: logURL) }
}

/// 8 秒 / 3 分 5 秒 / 2 小时 14 分
func durationText(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded()))
    if s < 60 { return "\(s) 秒" }
    if s < 3600 { return s % 60 == 0 ? "\(s / 60) 分钟" : "\(s / 60) 分 \(s % 60) 秒" }
    let minutes = s % 3600 / 60
    return minutes == 0 ? "\(s / 3600) 小时" : "\(s / 3600) 小时 \(minutes) 分"
}

// MARK: - 睡眠记录：分清「Mac 睡着了」和「iCloud 送得慢」

enum Power {
    private static var sleepStart: Date?
    private static var sleeps: [(start: Date, end: Date)] = []

    static func willSleep() { sleepStart = Date() }

    /// 返回这次睡了多久
    static func didWake() -> TimeInterval? {
        guard let start = sleepStart else { return nil }
        sleepStart = nil
        let now = Date()
        sleeps.append((start, now))
        sleeps.removeAll { $0.end < now.addingTimeInterval(-7 * 24 * 3600) }
        return now.timeIntervalSince(start)
    }

    /// from…to 这段时间里 Mac 睡了多久
    static func asleep(from: Date, to: Date) -> TimeInterval {
        sleeps.reduce(0) { sum, s in sum + max(0, min(to, s.end).timeIntervalSince(max(from, s.start))) }
    }
}

// MARK: - 新建便笺

enum StickyMaker {
    /// 便笺 App 在 Info.plist 里登记的服务名是 "Make Sticky"，菜单里显示的是「Make New Sticky Note / 新建便笺」。
    static let serviceNames = ["Make Sticky", "Make New Sticky Note"]
    static var askedForAccessibility = false

    static func make(_ text: String) -> Bool {
        let previous = NSWorkspace.shared.frontmostApplication
        // 首选：通过「便笺」自己的菜单新建并写入。不把便笺调到前台，也不会多出空白便笺（需要允许 Binsen 控制「便笺」）。
        var ok = viaAccessibility(text)
        if !ok { ok = viaService(text) || viaUIScripting(text) }
        if ok, restoreFocus { giveFocusBack(to: previous) }
        return ok
    }

    static var stickiesApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: stickiesBundleID).first { !$0.isTerminated }
    }

    /// 一边转动 RunLoop（让系统消息照常进来），一边等条件成立
    @discardableResult
    static func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return true
    }

    /// 在后台启动便笺（不抢焦点），等它启动完成
    static func launchStickies() -> NSRunningApplication? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: stickiesBundleID) else {
            logLine("找不到「便笺」App")
            return nil
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            guard let error else { return }
            DispatchQueue.main.async { logLine("启动「便笺」失败：\(error.localizedDescription)") }
        }
        waitUntil(10) { stickiesApp?.isFinishedLaunching == true }
        if stickiesApp == nil { logLine("「便笺」10 秒内没有启动起来") }
        return stickiesApp
    }

    static func viaAccessibility(_ text: String) -> Bool {
        let wasRunning = stickiesApp != nil
        guard let app = wasRunning ? stickiesApp : launchStickies() else { return false }
        let pid = app.processIdentifier

        // 刚启动的便笺要过一会儿才响应辅助功能，多等几秒，别过早判成「没权限」
        guard waitUntil(wasRunning ? 0.3 : 5, { StickiesAX.canControl(pid) }) else {
            requestPermissionOnce()
            return false
        }

        if !wasRunning {
            // 便笺刚启动：等它把上次的便笺都摆出来，再优先写进它自带的那张空白便笺，免得多出一张空白
            StickiesAX.waitForWindowsToSettle(pid)
            if let filled = StickiesAX.fillBlankNote(pid: pid, text: text) {
                logLine("已写进便笺启动时自带的空白便笺" + NotePlacer.place(filled, pid: pid))
                return true
            }
        }

        // 用便笺菜单里的「新建便笺」（⌘N）建一张，再写入
        let before = StickiesAX.windows(pid)
        guard waitUntil(wasRunning ? 0.3 : 3, { StickiesAX.pressNewNote(pid) }) else {
            logLine("便笺的菜单还没准备好，改用系统服务")
            return false
        }
        guard let created = StickiesAX.waitForNewWindow(pid, excluding: before, timeout: 3) else {
            logLine("便笺已新建，但读不到新窗口，改用系统服务")
            return false
        }
        guard waitUntil(1.5, { StickiesAX.write(text, into: created, isNewNote: true) }) else {
            logLine("新便笺已建好，但没能写入文字")
            return false
        }
        logLine("已通过便笺菜单新建并写入" + NotePlacer.place(created, pid: pid))
        return true
    }

    /// 没有控制「便笺」的权限时，每个新版本只弹一次系统授权提示
    static func requestPermissionOnce() {
        let executable = Bundle.main.executablePath ?? ""
        let modified = (try? FileManager.default.attributesOfItem(atPath: executable)[.modificationDate] as? Date) ?? Date()
        let stamp = String(Int(modified.timeIntervalSince1970))
        logLine("没有控制「便笺」的权限：便笺会被调到前台，便笺没打开时可能多出一张空白便笺")
        if settings.string(forKey: "AXPromptedBuild") != stamp {
            settings.set(stamp, forKey: "AXPromptedBuild")
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
    }

    /// 备用路径一：调用便笺的系统服务，不需要任何额外权限。
    static func viaService(_ text: String) -> Bool {
        for name in serviceNames {
            let pasteboard = NSPasteboard.withUniqueName()
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            let ok = NSPerformService(name, pasteboard)
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { pasteboard.releaseGlobally() }
            if ok {
                logLine("已通过系统服务新建便笺")
                return true
            }
        }
        logLine("系统服务「新建便笺」调用失败，尝试备用方式")
        return false
    }

    /// 备用路径二：⌘N 新建 + ⌘V 粘贴。需要在「辅助功能」里允许 Binsen。
    static func viaUIScripting(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else {
            if !askedForAccessibility {
                askedForAccessibility = true
                _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            }
            logLine("备用方式需要「辅助功能」权限：系统设置 → 隐私与安全性 → 辅助功能 → 打开 Binsen")
            return false
        }

        let general = NSPasteboard.general
        let saved: [NSPasteboardItem] = (general.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { _ = copy.setData(data, forType: type) }
            }
            return copy
        }
        general.clearContents()
        general.setString(text, forType: .string)

        let script = """
        tell application id "\(stickiesBundleID)" to activate
        delay 0.5
        tell application "System Events" to tell process "Stickies"
            keystroke "n" using command down
            delay 0.3
            keystroke "v" using command down
        end tell
        """
        var error: NSDictionary?
        _ = NSAppleScript(source: script)?.executeAndReturnError(&error)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            general.clearContents()
            if !saved.isEmpty { _ = general.writeObjects(saved) }
        }

        if let error {
            logLine("备用方式失败：\(error)")
            return false
        }
        return true
    }

    static let neverRefocus: Set<String> = [stickiesBundleID, "com.apple.loginwindow", "com.apple.ScreenSaver.Engine"]

    /// 把焦点还给原来的 App。
    /// 有辅助功能权限时，直接把它设为前台（最可靠）；
    /// 否则用 macOS 14+ 的协作激活：先让自己短暂到前台（没有窗口，看不到），再把焦点让给它。
    static func giveFocusBack(to app: NSRunningApplication?) {
        guard let app, !app.isTerminated,
              !neverRefocus.contains(app.bundleIdentifier ?? ""),
              app.processIdentifier != getpid() else { return }

        func isFront() -> Bool {
            NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        }
        func frontViaAccessibility() {
            _ = StickiesAX.set(AXUIElementCreateApplication(app.processIdentifier), "AXFrontmost", true as AnyObject)
        }
        func frontViaYield() {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                if #available(macOS 14.0, *) {
                    NSApp.yieldActivation(to: app)
                    _ = app.activate(from: NSRunningApplication.current, options: [])
                } else {
                    _ = app.activate(options: [.activateIgnoringOtherApps])
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if isFront() { return }
            let trusted = AXIsProcessTrusted()
            if trusted { frontViaAccessibility() } else { frontViaYield() }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if isFront() { return }
                if trusted { frontViaYield() } else { frontViaAccessibility() }   // 换另一种方式再试一次

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !isFront() {
                        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知"
                        logLine("焦点没能还给「\(app.localizedName ?? "原来的 App")」，当前前台：\(front)（辅助功能：\(trusted ? "已授权" : "未授权")）")
                    }
                }
            }
        }
    }
}

// MARK: - 读写便笺窗口（需要辅助功能权限）

enum StickiesAX {
    static func copy(_ element: AXUIElement, _ name: String) -> (AXError, AnyObject?) {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return (error, value)
    }

    static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        let (error, value) = copy(element, name)
        return error == .success ? value : nil
    }

    static func set(_ element: AXUIElement, _ name: String, _ value: AnyObject) -> Bool {
        AXUIElementSetAttributeValue(element, name as CFString, value) == .success
    }

    /// 能读到便笺的辅助功能信息，就说明有控制它的权限
    static func canControl(_ pid: pid_t) -> Bool {
        copy(AXUIElementCreateApplication(pid), "AXRole").0 == .success
    }

    static func windows(_ pid: pid_t) -> [AXUIElement] {
        (attribute(AXUIElementCreateApplication(pid), "AXWindows") as? [AXUIElement]) ?? []
    }

    /// 便笺刚启动时会陆续恢复上次的便笺，等窗口数量稳定下来（最多 4 秒）
    static func waitForWindowsToSettle(_ pid: pid_t) {
        let deadline = Date().addingTimeInterval(4)
        var lastCount = -1
        var stableSince = Date()
        while Date() < deadline {
            let count = windows(pid).count
            if count != lastCount {
                lastCount = count
                stableSince = Date()
            } else if Date().timeIntervalSince(stableSince) >= (count == 0 ? 1.5 : 0.6) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    static func textArea(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        if (attribute(element, "AXRole") as? String) == "AXTextArea" { return element }
        guard depth < 6, let children = attribute(element, "AXChildren") as? [AXUIElement] else { return nil }
        for child in children {
            if let found = textArea(in: child, depth: depth + 1) { return found }
        }
        return nil
    }

    /// 只往空白便笺里写，避免覆盖已有内容。
    /// isNewNote：刚用 ⌘N 建的那张，如果发现文字已经在里面（上一轮其实写成功了），也算成功，避免重复写。
    static func write(_ text: String, into window: AXUIElement, isNewNote: Bool = false) -> Bool {
        guard let area = textArea(in: window) else { return false }
        let probe = String(text.prefix { $0 != "\n" }.prefix(10))
        let current = (attribute(area, "AXValue") as? String) ?? ""
        if isNewNote, !probe.isEmpty, current.contains(probe) { return true }
        guard current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        let wrote = set(area, "AXSelectedText", text as CFString) || set(area, "AXValue", text as CFString)
        let after = (attribute(area, "AXValue") as? String) ?? ""
        return wrote && after.contains(probe)
    }

    /// 写进第一张空白便笺，返回那张便笺的窗口
    static func fillBlankNote(pid: pid_t, text: String) -> AXUIElement? {
        windows(pid).first { write(text, into: $0) }
    }

    /// 窗口的位置和大小（辅助功能坐标：原点在主屏左上角，y 往下）
    static func frame(_ window: AXUIElement) -> CGRect? {
        guard let position = attribute(window, "AXPosition"), let size = attribute(window, "AXSize"),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    static func move(_ window: AXUIElement, to point: CGPoint) -> Bool {
        var origin = point
        guard let value = AXValueCreate(.cgPoint, &origin) else { return false }
        return set(window, "AXPosition", value)
    }

    /// 按快捷键在便笺的菜单里找菜单项，不依赖界面语言。modifiers：0 = 只按 ⌘
    static func menuItem(in element: AXUIElement, key: String, modifiers: Int, depth: Int = 0) -> AXUIElement? {
        if (attribute(element, "AXRole") as? String) == "AXMenuItem",
           (attribute(element, "AXMenuItemCmdChar") as? String)?.uppercased() == key,
           ((attribute(element, "AXMenuItemCmdModifiers") as? Int) ?? -1) == modifiers {
            return element
        }
        guard depth < 4, let children = attribute(element, "AXChildren") as? [AXUIElement] else { return nil }
        for child in children {
            if let found = menuItem(in: child, key: key, modifiers: modifiers, depth: depth + 1) { return found }
        }
        return nil
    }

    static func pressMenuItem(_ pid: pid_t, key: String, modifiers: Int) -> Bool {
        guard let raw = attribute(AXUIElementCreateApplication(pid), "AXMenuBar"),
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { return false }
        guard let item = menuItem(in: raw as! AXUIElement, key: key, modifiers: modifiers) else { return false }
        return AXUIElementPerformAction(item, "AXPress" as CFString) == .success
    }

    /// 「文件 › 新建便笺」⌘N
    static func pressNewNote(_ pid: pid_t) -> Bool {
        pressMenuItem(pid, key: "N", modifiers: 0)
    }

    static func waitForNewWindow(_ pid: pid_t, excluding before: [AXUIElement], timeout: TimeInterval) -> AXUIElement? {
        var found: AXUIElement?
        StickyMaker.waitUntil(timeout) {
            found = windows(pid).first { window in !before.contains { CFEqual($0, window) } }
            return found != nil
        }
        return found
    }
}

// MARK: - 新便笺放在哪儿：默认从屏幕右上角往下排，不压住已有的便笺

enum NotePlacer {
    static let margin: CGFloat = 16      // 离屏幕边缘
    static let gap: CGFloat = 12         // 右上角排列时便笺之间的间距
    static let step: CGFloat = 26        // 错开时每次挪多少，正好露出上一张的标题栏
    static let maxColumns = 2            // 右上角最多排两列，再多就在右上角依次错开

    /// 把新便笺挪到合适的位置，返回接在日志后面的说明；不挪时返回空字符串
    static func place(_ window: AXUIElement, pid: pid_t) -> String {
        let mode = notePlacement
        guard mode != "off", let frame = StickiesAX.frame(window), let area = visibleArea(around: frame) else { return "" }
        let others = StickiesAX.windows(pid).filter { !CFEqual($0, window) }.compactMap { StickiesAX.frame($0) }
        let result: (CGPoint, String)
        if mode == "cascade" {
            result = (cascade(from: frame.origin, size: frame.size, in: area, avoiding: others, dx: step), "往右下错开")
        } else {
            result = topRight(size: frame.size, in: area, avoiding: others)
        }
        let (target, note) = result
        if abs(target.x - frame.minX) < 1, abs(target.y - frame.minY) < 1 { return "，\(note)" }
        return StickiesAX.move(window, to: target) ? "，\(note)" : "（没能挪动位置）"
    }

    /// 从右上角往下排，一列排满往左再起一列，跳过已有便笺占着的位置；都占满了就在右上角依次错开
    static func topRight(size: CGSize, in area: CGRect, avoiding others: [CGRect]) -> (CGPoint, String) {
        let rows = max(1, Int((area.height - 2 * margin + gap) / (size.height + gap)))
        for column in 0..<maxColumns {
            for row in 0..<rows {
                let origin = CGPoint(x: area.maxX - margin - size.width - CGFloat(column) * (size.width + gap),
                                     y: area.minY + margin + CGFloat(row) * (size.height + gap))
                let slot = CGRect(origin: origin, size: size)
                guard area.contains(slot) else { continue }
                if !others.contains(where: { $0.insetBy(dx: 4, dy: 4).intersects(slot) }) {
                    return (origin, "放在右上角")
                }
            }
        }
        let corner = CGPoint(x: area.maxX - margin - size.width, y: area.minY + margin)
        return (cascade(from: corner, size: size, in: area, avoiding: others, dx: -step), "放在右上角（排满了，错开放）")
    }

    /// 从 start 开始每次往下挪 step、横向挪 dx，直到这里没有别的便笺（左上角挨得很近就算占着）；到屏幕边就绕回去
    static func cascade(from start: CGPoint, size: CGSize, in area: CGRect, avoiding others: [CGRect], dx: CGFloat) -> CGPoint {
        var point = clamp(start, size: size, in: area)
        for _ in 0..<64 {
            if !others.contains(where: { abs($0.minX - point.x) < 8 && abs($0.minY - point.y) < 8 }) { break }
            point.x += dx
            point.y += step
            if point.y + size.height > area.maxY { point.y = area.minY + margin }
            if point.x + size.width > area.maxX { point.x = area.minX + margin }
            if point.x < area.minX { point.x = area.maxX - margin - size.width }
        }
        return clamp(point, size: size, in: area)
    }

    static func clamp(_ point: CGPoint, size: CGSize, in area: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, area.minX), max(area.minX, area.maxX - size.width)),
                y: min(max(point.y, area.minY), max(area.minY, area.maxY - size.height)))
    }

    /// 便笺所在屏幕去掉菜单栏和程序坞后的区域，换成辅助功能坐标（原点在主屏左上角，y 往下）
    static func visibleArea(around frame: CGRect) -> CGRect? {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return nil }
        let flip = { (r: CGRect) -> CGRect in
            CGRect(x: r.minX, y: primary.frame.maxY - r.maxY, width: r.width, height: r.height)
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let screen = screens.first { flip($0.frame).contains(center) } ?? NSScreen.main ?? primary
        return flip(screen.visibleFrame)
    }
}

// MARK: - 监听收件箱：文件一到就处理，不用干等下一次定时检查

final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init(path: String, onChange: @escaping () -> Void) {
        self.onChange = onChange
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot)
        guard let stream = FSEventStreamCreate(kCFAllocatorDefault, callback, &context, [path] as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.2, flags) else {
            logLine("提示：无法监听收件箱的变化，只靠每 2 秒检查一次")
            return
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }
}

// MARK: - 收件箱

final class Inbox {
    let url: URL
    var archiveURL: URL { url.appendingPathComponent(archiveFolderName, isDirectory: true) }

    private struct Item {
        let url: URL
        let created: Date      // iPhone 存下这个文件的时间（iCloud 会原样带过来）
        let seen: Date         // Mac 第一次看到它的时间
        var text: String?
        var reading = false
        var readStarted: Date?
        var readFailures = 0
        var makeFailures = 0
        var retryAt = Date.distantPast
        var warnedStuck = false
    }

    private var items: [String: Item] = [:]
    private var finished: Set<String> = []   // 归档失败时，记住已贴过的文件，避免重复贴
    private var busy = false
    private var rescanNeeded = false
    private var scanScheduled = false
    private var warnedMissingFolder = false
    private let readQueue = DispatchQueue(label: "io.github.qinov5.binsen.read", qos: .userInitiated,
                                          attributes: .concurrent)

    init(url: URL) { self.url = url }

    func prepare() {
        do {
            try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: true)
            warnedMissingFolder = false
        } catch {
            if !warnedMissingFolder {
                warnedMissingFolder = true
                logLine("无法创建收件箱 \(url.path)：\(error.localizedDescription)")
            }
        }
    }

    /// 合并短时间内的多次触发
    func scanSoon(after delay: TimeInterval = 0.1) {
        guard !scanScheduled else { return }
        scanScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            scanScheduled = false
            scan()
        }
    }

    func scan() {
        if busy {
            rescanNeeded = true
            return
        }
        busy = true
        defer {
            busy = false
            if rescanNeeded {
                rescanNeeded = false
                scanSoon()
            }
        }

        prepare()
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .creationDateKey]
        guard let entries = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys) else { return }
        let now = Date()

        var present: Set<String> = []
        for entry in entries {
            let name = entry.lastPathComponent
            if name.hasPrefix(".") {
                if name.hasSuffix(".icloud") { requestDownload(placeholder: entry) }
                continue
            }
            let values = try? entry.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true { continue }
            guard acceptedExtensions.contains(entry.pathExtension.lowercased()) else { continue }
            let created = values?.creationDate ?? now
            let key = "\(name)|\(created.timeIntervalSince1970)"
            present.insert(key)
            if finished.contains(key) || items[key] != nil { continue }
            items[key] = Item(url: entry, created: created, seen: now)
            logArrival(name: name, created: created, seen: now)
        }
        // 文件已经不在了（被删掉或移走）就不再管它
        for key in Array(items.keys) where !present.contains(key) { items[key] = nil }
        finished.formIntersection(present)

        let order = items.keys.sorted { (items[$0]?.created ?? now) < (items[$1]?.created ?? now) }
        for key in order {
            guard let item = items[key], Date() >= item.retryAt else { continue }
            if item.text != nil {
                paste(key)
            } else if !item.reading {
                startReading(key)
            } else if let started = item.readStarted, Date().timeIntervalSince(started) > 60, !item.warnedStuck {
                items[key]?.warnedStuck = true
                logLine("iCloud 还在下载内容（已等 \(durationText(Date().timeIntervalSince(started)))）：\(item.url.lastPathComponent)")
                requestDownload(of: item.url)
            }
        }
    }

    /// 记下 iCloud 花了多久才把文件送到这台 Mac，方便判断慢在哪里
    private func logArrival(name: String, created: Date, seen: Date) {
        let waited = seen.timeIntervalSince(created)
        var note = "收到：\(name)（\(clockFormatter.string(from: created)) 存入"
        if created < launchedAt {
            note += "，Binsen 启动时发现"
        } else if waited >= 5 {
            note += "，iCloud 用了 \(durationText(waited)) 才送到这台 Mac"
            let slept = Power.asleep(from: created, to: seen)
            if slept >= 60 {
                note += "，其中 Mac 睡眠 \(durationText(slept))"
            } else if waited >= 120 {
                note += "；期间 Mac 一直醒着，多半是 iPhone 迟迟没有上传（打开「文件」App 才会传），改用提醒事项通道可避免，见 README"
            }
        }
        logLine(note + "）")
    }

    private func startReading(_ key: String) {
        guard var item = items[key] else { return }
        item.reading = true
        item.readStarted = Date()
        items[key] = item
        let file = item.url
        readQueue.async {
            let result = Inbox.readText(file)
            DispatchQueue.main.async { self.finishReading(key, result) }
        }
    }

    private func finishReading(_ key: String, _ result: Result<String, Error>) {
        guard var item = items[key] else { return }
        item.reading = false
        let waited = Date().timeIntervalSince(item.readStarted ?? Date())
        switch result {
        case .success(let text):
            item.text = text
            item.readFailures = 0
            if waited >= 3 {
                logLine("内容已从 iCloud 下载好（等了 \(durationText(waited))）：\(item.url.lastPathComponent)")
            }
        case .failure(let error):
            item.readFailures += 1
            let n = item.readFailures
            item.retryAt = Date().addingTimeInterval(min(30, Double(n) * 2))
            if n == 1 || n % 20 == 0 {
                logLine("读不到内容（第 \(n) 次，已请求 iCloud 下载）：\(item.url.lastPathComponent) · \(describe(error))")
            }
            if n == 1 || n % 5 == 0 { requestDownload(of: item.url) }
        }
        items[key] = item
        scanSoon()
    }

    private func paste(_ key: String) {
        guard var item = items[key], let text = item.text else { return }
        let name = item.url.lastPathComponent
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            archive(item.url, key: key)
            items[key] = nil
            return
        }

        if StickyMaker.make(content) {
            logLine("已贴到便笺：\(name)（从存入到贴出共 \(durationText(Date().timeIntervalSince(item.created)))）")
            archive(item.url, key: key)
            items[key] = nil
        } else {
            // 不放弃：2、4、8 … 秒后重试，最长每分钟一次，直到贴上为止
            item.makeFailures += 1
            let n = item.makeFailures
            item.retryAt = Date().addingTimeInterval(min(60, pow(2, Double(min(n, 6)))))
            if n <= 3 || n % 10 == 0 { logLine("新建便笺失败（第 \(n) 次，稍后自动重试）：\(name)") }
            items[key] = item
        }
    }

    static func readText(_ file: URL) -> Result<String, Error> {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            return .failure(error)
        }
        if data.starts(with: Array("{\\rtf".utf8)),
           let rich = NSAttributedString(rtf: data, documentAttributes: nil) {
            return .success(rich.string)
        }
        if let text = String(data: data, encoding: .utf8) {
            return .success(text.replacingOccurrences(of: "\u{FEFF}", with: ""))
        }
        var encoding = String.Encoding.utf8
        if let text = try? String(contentsOf: file, usedEncoding: &encoding) {
            return .success(text.replacingOccurrences(of: "\u{FEFF}", with: ""))
        }
        return .failure(CocoaError(.fileReadInapplicableStringEncoding))
    }

    /// iPhone 同步过来的文件可能只有占位（还没真正下载到 Mac），主动请求下载
    private func requestDownload(of file: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: file)
        let brctl = Process()
        brctl.executableURL = URL(fileURLWithPath: "/usr/bin/brctl")
        brctl.arguments = ["download", file.path]
        brctl.standardOutput = FileHandle.nullDevice
        brctl.standardError = FileHandle.nullDevice
        try? brctl.run()
    }

    private func archive(_ file: URL, key: String) {
        let fm = FileManager.default
        let base = file.deletingPathExtension().lastPathComponent
        let ext = file.pathExtension
        var destination = archiveURL.appendingPathComponent(file.lastPathComponent)
        var n = 2
        while fm.fileExists(atPath: destination.path) {
            destination = archiveURL.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        do {
            try fm.moveItem(at: file, to: destination)
            // 记下归档的时间，到期清理以它为准
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
        } catch {
            finished.insert(key)
            logLine("归档失败（不会重复贴）：\(file.lastPathComponent) · \(error.localizedDescription)")
        }
    }

    /// 删掉「已处理」里归档早于 cutoff 的原文，返回删了几个。只动 Binsen 自己归档的文本文件。
    func cleanUpArchive(before cutoff: Date) -> Int {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .creationDateKey, .contentModificationDateKey]
        guard let entries = try? fm.contentsOfDirectory(at: archiveURL, includingPropertiesForKeys: Array(keys),
                                                         options: [.skipsHiddenFiles]) else { return 0 }
        var removed = 0
        for entry in entries where acceptedExtensions.contains(entry.pathExtension.lowercased()) {
            guard let values = try? entry.resourceValues(forKeys: keys), values.isDirectory != true else { continue }
            let stamp = [values.creationDate, values.contentModificationDate].compactMap { $0 }.max() ?? Date()
            guard stamp < cutoff else { continue }
            do {
                try fm.removeItem(at: entry)
                removed += 1
            } catch {
                let name = entry.lastPathComponent
                DispatchQueue.main.async { logLine("清理失败：\(name) · \(error.localizedDescription)") }
            }
        }
        return removed
    }

    private func requestDownload(placeholder: URL) {
        // 旧版 iCloud 的占位文件：".名字.txt.icloud"
        var name = placeholder.lastPathComponent
        name.removeFirst()
        name = String(name.dropLast(".icloud".count))
        let real = placeholder.deletingLastPathComponent().appendingPathComponent(name)
        try? FileManager.default.startDownloadingUbiquitousItem(at: real)
    }
}

// MARK: - 提醒事项通道
// iPhone 快捷指令「添加新提醒事项」到「Binsen」列表 → 提醒事项走 CloudKit，一般几秒就同步到 Mac
// → 读到后贴成便笺，再把这条提醒事项标记为已完成（在提醒事项里随时可以清除已完成项）。

final class RemindersInbox {
    let store = EKEventStore()
    private var authorized = false
    private var busy = false
    private var rescanNeeded = false
    private var scanScheduled = false
    private var warnedNoList = false
    private var seen: Set<String> = []                       // 已记过「收到」的
    private var pasted: Set<String> = []                     // 已贴出、但标记完成失败的，避免重复贴
    private var failures: [String: (count: Int, retryAt: Date)] = [:]
    private var observer: NSObjectProtocol?
    private var warnedCustomList = false

    static func requestAccess(_ store: EKEventStore, _ done: @escaping (Bool) -> Void) {
        let finish: (Bool, Error?) -> Void = { granted, error in
            DispatchQueue.main.async {
                if let error { logLine("提醒事项：请求权限出错 \(describe(error))") }
                done(granted)
            }
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToReminders(completion: finish)
        } else {
            store.requestAccess(to: .reminder, completion: finish)
        }
    }

    static func findList(_ store: EKEventStore) -> EKCalendar? {
        store.calendars(for: .reminder).first { $0.title == remindersListName }
    }

    func start() {
        RemindersInbox.requestAccess(store) { [weak self] granted in
            guard let self else { return }
            self.authorized = granted
            guard granted else {
                logLine("提醒事项：没有访问权限，这条通道先不开。到 系统设置 → 隐私与安全性 → 提醒事项 → 打开 Binsen，再重启 Binsen")
                return
            }
            self.store.refreshSourcesIfNecessary()
            self.ensureList()
            self.observer = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged, object: self.store, queue: .main) { [weak self] _ in self?.scanSoon() }
            logLine("提醒事项：已开启，监听列表「\(remindersListName)」")
            self.scanSoon()
        }
    }

    /// 没有「Binsen」列表就在 iCloud 账户里新建一个，iPhone 上随后就能选到
    private func ensureList() {
        guard RemindersInbox.findList(store) == nil else { return }
        let sources = store.sources.filter { !$0.calendars(for: .reminder).isEmpty }
        guard let source = sources.first(where: { $0.title == "iCloud" })
                ?? store.defaultCalendarForNewReminders()?.source ?? sources.first else {
            logLine("提醒事项：找不到可以新建列表的账户，请在「提醒事项」App 里手动新建列表「\(remindersListName)」")
            return
        }
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = remindersListName
        calendar.source = source
        do {
            try store.saveCalendar(calendar, commit: true)
            logLine("提醒事项：已在「\(source.title)」里新建列表「\(remindersListName)」")
        } catch {
            logLine("提醒事项：新建列表失败（\(describe(error))），请在「提醒事项」App 里手动新建「\(remindersListName)」")
        }
    }

    /// 定时调用：主动向 iCloud 要一次新数据，不完全依赖推送
    func refresh() {
        guard authorized else { return }
        store.refreshSourcesIfNecessary()
        scanSoon()
    }

    func scanSoon(after delay: TimeInterval = 0.3) {
        guard authorized, !scanScheduled else { return }
        scanScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            scanScheduled = false
            scan()
        }
    }

    private func scan() {
        if busy {
            rescanNeeded = true
            return
        }
        guard let list = RemindersInbox.findList(store) else {
            if !warnedNoList {
                warnedNoList = true
                logLine("提醒事项：还没有列表「\(remindersListName)」")
                ensureList()
            }
            return
        }
        warnedNoList = false
        busy = true
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [list])
        _ = store.fetchReminders(matching: predicate) { [weak self] reminders in
            DispatchQueue.main.async {
                guard let self else { return }
                self.handle(reminders ?? [])
                self.busy = false
                if self.rescanNeeded {
                    self.rescanNeeded = false
                    self.scanSoon()
                }
            }
        }
    }

    private func handle(_ reminders: [EKReminder]) {
        let now = Date()
        for reminder in reminders.sorted(by: { ($0.creationDate ?? now) < ($1.creationDate ?? now) }) {
            let id = reminder.calendarItemIdentifier
            if let failure = failures[id], Date() < failure.retryAt { continue }
            let created = reminder.creationDate ?? now
            let text = [reminder.title, reminder.notes]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            let preview = String(text.prefix { $0 != "\n" }.prefix(24))

            if !seen.contains(id) {
                seen.insert(id)
                let waited = Date().timeIntervalSince(created)
                var note = "收到：提醒事项「\(preview)」（\(clockFormatter.string(from: created)) 添加"
                if created < launchedAt {
                    note += "，Binsen 启动时发现"
                } else if waited >= 5 {
                    note += "，iCloud 用了 \(durationText(waited)) 才送到这台 Mac"
                    let slept = Power.asleep(from: created, to: Date())
                    if slept >= 60 { note += "，其中 Mac 睡眠 \(durationText(slept))" }
                }
                logLine(note + "）")
            }

            if text.isEmpty || pasted.contains(id) {
                complete(reminder)
                continue
            }
            if StickyMaker.make(text) {
                failures[id] = nil
                logLine("已贴到便笺：提醒事项「\(preview)」（从添加到贴出共 \(durationText(Date().timeIntervalSince(created)))）")
                pasted.insert(id)
                complete(reminder)
            } else {
                let n = (failures[id]?.count ?? 0) + 1
                failures[id] = (n, Date().addingTimeInterval(min(60, pow(2, Double(min(n, 6))))))
                if n <= 3 || n % 10 == 0 { logLine("新建便笺失败（第 \(n) 次，稍后自动重试）：提醒事项「\(preview)」") }
            }
        }
    }

    private func complete(_ reminder: EKReminder) {
        let id = reminder.calendarItemIdentifier
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
            pasted.remove(id)
            seen.remove(id)
        } catch {
            logLine("提醒事项：标记完成失败（\(describe(error))），之后会再试，不会重复贴")
        }
    }

    /// 删掉列表里完成时间早于 cutoff 的提醒事项（贴成便笺后被标记为已完成的原文）。
    /// 列表是自己指定的（不是默认的 Binsen）时，只有明确设置过 KeepDays 才清理，免得删掉你自己的已完成事项。
    func cleanUp(before cutoff: Date) {
        guard authorized else { return }
        guard remindersListName == "Binsen" || settings.object(forKey: "KeepDays") != nil else {
            if !warnedCustomList {
                warnedCustomList = true
                logLine("提醒事项：列表「\(remindersListName)」是自己指定的，不自动清理里面的已完成项；需要清理就设置 KeepDays")
            }
            return
        }
        guard let list = RemindersInbox.findList(store) else { return }
        let predicate = store.predicateForCompletedReminders(withCompletionDateStarting: nil, ending: cutoff,
                                                             calendars: [list])
        _ = store.fetchReminders(matching: predicate) { [weak self] reminders in
            DispatchQueue.main.async {
                guard let self, let reminders, !reminders.isEmpty else { return }
                var removed = 0
                for reminder in reminders {
                    if (try? self.store.remove(reminder, commit: false)) != nil { removed += 1 }
                }
                do {
                    try self.store.commit()
                    logLine("清理：删除了提醒事项「\(remindersListName)」里 \(removed) 条完成超过 \(keepDays) 天的原文")
                } catch {
                    self.store.reset()
                    logLine("清理提醒事项失败：\(describe(error))")
                }
            }
        }
    }

    /// --remind：往列表里加一条，用来自检整条提醒事项通道
    static func addForTest(_ text: String) -> Bool {
        let store = EKEventStore()
        var granted: Bool?
        requestAccess(store) { granted = $0 }
        StickyMaker.waitUntil(90) { granted != nil }
        guard granted == true else {
            print("没有提醒事项权限：系统设置 → 隐私与安全性 → 提醒事项 → 打开 Binsen")
            return false
        }
        StickyMaker.waitUntil(10) { findList(store) != nil }
        guard let list = findList(store) else {
            print("还没有提醒事项列表「\(remindersListName)」")
            return false
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = text
        reminder.calendar = list
        do {
            try store.save(reminder, commit: true)
            return true
        } catch {
            print("添加提醒事项失败：\(describe(error))")
            return false
        }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    let inbox = Inbox(url: inboxURL)
    var reminders: RemindersInbox?
    var timer: Timer?
    var ticks = 0
    var watcher: FolderWatcher?
    var activity: NSObjectProtocol?
    var cleanupTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        trimLogIfNeeded()
        logLine("启动 v\(appVersion)，收件箱：\(inbox.url.path)")
        checkAccessibility()
        if materializeResult != 0 { logLine("提示：无法开启 iCloud 按需下载（返回 \(materializeResult)），改用主动下载") }

        // 没有窗口的后台 App 会被系统「App Nap」，定时检查可能被推迟几十秒；声明正在为用户工作，避免被压低
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "及时把 iPhone 发来的文字贴进便笺")

        inbox.prepare()
        watcher = FolderWatcher(path: inbox.url.path) { [weak self] in self?.inbox.scanSoon(after: 0.2) }
        inbox.scan()

        if useReminders {
            let reminders = RemindersInbox()
            reminders.start()
            self.reminders = reminders
        } else {
            logLine("提醒事项通道已关闭（UseReminders = false）")
        }

        // 兜底：每 2 秒再看一次收件箱（也负责失败后的重试），每 10 秒看一次提醒事项，每分钟主动向 iCloud 刷新一次
        let timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.inbox.scan()
            self.ticks += 1
            if self.ticks % 30 == 0 {
                self.reminders?.refresh()
            } else if self.ticks % 5 == 0 {
                self.reminders?.scanSoon()
            }
        }
        timer.tolerance = 0.5
        self.timer = timer

        // 已处理的原文到期自动删除：启动 1 分钟后先清一次，之后每 6 小时一次
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in self?.cleanUp() }
        let cleanupTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.cleanUp()
        }
        cleanupTimer.tolerance = 600
        self.cleanupTimer = cleanupTimer

        let center = NSWorkspace.shared.notificationCenter
        _ = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            Power.willSleep()
            logLine("Mac 进入睡眠：睡眠期间收不到新便笺，唤醒后会自动补上")
        }
        _ = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            let slept = Power.didWake()
            logLine("Mac 已唤醒" + (slept.map { "（睡了 \(durationText($0))）" } ?? ""))
            self?.inbox.scanSoon()
            self?.reminders?.refresh()
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            _ = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.inbox.scanSoon() }
        }
    }

    /// 删掉放了超过 KeepDays 天的原文：iCloud 云盘「已处理」里的文件、提醒事项列表里已完成的条目
    func cleanUp() {
        let days = keepDays
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let inbox = self.inbox
        DispatchQueue.global(qos: .utility).async {
            let removed = inbox.cleanUpArchive(before: cutoff)
            guard removed > 0 else { return }
            DispatchQueue.main.async { logLine("清理：删除了「\(archiveFolderName)」里 \(removed) 个超过 \(days) 天的原文") }
        }
        reminders?.cleanUp(before: cutoff)
    }

    func checkAccessibility() {
        if AXIsProcessTrusted() {
            logLine("权限：可以控制所有 App")
        } else if let pid = StickyMaker.stickiesApp?.processIdentifier, StickiesAX.canControl(pid) {
            logLine("权限：可以控制「便笺」")
        } else {
            logLine("权限：尚未确认能否控制「便笺」（第一次新建便笺时会检查）")
        }
    }
}

let arguments = CommandLine.arguments
let app = NSApplication.shared

app.setActivationPolicy(.accessory)

if arguments.contains("--version") {
    print("Binsen \(appVersion)")
    exit(0)
}

if let i = arguments.firstIndex(of: "--test") {
    let text = i + 1 < arguments.count ? arguments[i + 1] : "Binsen 自检 \(logDateFormatter.string(from: Date()))"
    let ok = StickyMaker.make(text)
    print(ok ? "OK" : "FAILED")
    RunLoop.main.run(until: Date().addingTimeInterval(2.5))
    exit(ok ? 0 : 1)
}

if let i = arguments.firstIndex(of: "--remind") {
    let text = i + 1 < arguments.count ? arguments[i + 1] : "Binsen 提醒事项自检 \(logDateFormatter.string(from: Date()))"
    let ok = RemindersInbox.addForTest(text)
    print(ok ? "OK" : "FAILED")
    exit(ok ? 0 : 1)
}

// 只保留一个常驻实例，避免同一条内容被贴两次
let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    .filter { $0.processIdentifier != getpid() }
if !others.isEmpty {
    logLine("已有实例在运行（pid \(others[0].processIdentifier)），本次退出")
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
