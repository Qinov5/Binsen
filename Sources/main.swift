// Binsen
// 监听 iCloud 云盘里的收件箱文件夹，把 iPhone 快捷指令存进来的文本变成 Mac 自带「便笺」里的一张新便笺。
//
// 用法：
//   Binsen                 常驻运行（由 LaunchAgent 启动）
//   Binsen --test [文字]    立即新建一张便笺，用来自检
//   Binsen --version

import AppKit
import ApplicationServices
import Foundation

let appVersion = "0.4.0"
let bundleID = "io.github.qinov5.binsen"
let stickiesBundleID = "com.apple.Stickies"
let archiveFolderName = "已处理"
let acceptedExtensions: Set<String> = ["", "txt", "text", "md", "markdown"]

let home = FileManager.default.homeDirectoryForCurrentUser
let settings = UserDefaults.standard

// 读到 iCloud 里还没下载到本机的文件时，让系统当场下载，而不是直接报错（后台进程默认不一定会下载）。
// 3 = IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES，0 = IOPOL_SCOPE_PROCESS，2 = IOPOL_MATERIALIZE_DATALESS_FILES_ON
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

// MARK: - 日志  ~/Library/Logs/Binsen.log

let logURL = home.appendingPathComponent("Library/Logs/Binsen.log")
let logDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
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
        NSRunningApplication.runningApplications(withBundleIdentifier: stickiesBundleID).first
    }

    static func viaAccessibility(_ text: String) -> Bool {
        let wasRunning = stickiesApp != nil
        if !wasRunning {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: stickiesBundleID) else { return false }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            NSWorkspace.shared.openApplication(at: url, configuration: config)
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline, !(stickiesApp?.isFinishedLaunching ?? false) {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
        }
        guard let pid = stickiesApp?.processIdentifier else { return false }
        guard StickiesAX.canControl(pid) else {
            requestPermissionOnce()
            return false
        }

        if !wasRunning {
            // 便笺刚启动：等它自带的空白便笺出现，直接写进这一张
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline, StickiesAX.windows(pid).isEmpty {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            if StickiesAX.fillBlankNote(pid: pid, text: text) {
                logLine("已写进便笺启动时自带的空白便笺")
                return true
            }
        }

        // 便笺已在运行：用它菜单里的「新建便笺」（⌘N）建一张，再写入
        let before = StickiesAX.windows(pid)
        guard StickiesAX.pressNewNote(pid),
              let window = StickiesAX.waitForNewWindow(pid, excluding: before, timeout: 2) else {
            logLine("通过菜单新建便笺失败，改用系统服务")
            return false
        }
        for _ in 0..<5 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            if StickiesAX.write(text, into: window) {
                logLine("已通过便笺菜单新建并写入")
                return true
            }
        }
        logLine("新便笺已建好，但没能写入文字")
        return false
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

    /// 主路径：调用系统服务，不需要任何额外权限。
    static func viaService(_ text: String) -> Bool {
        for name in serviceNames {
            let pasteboard = NSPasteboard.withUniqueName()
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            let ok = NSPerformService(name, pasteboard)
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { pasteboard.releaseGlobally() }
            if ok { return true }
        }
        logLine("系统服务「新建便笺」调用失败，尝试备用方式")
        return false
    }

    /// 备用路径：⌘N 新建 + ⌘V 粘贴。需要在「辅助功能」里允许 Binsen。
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

    static func textArea(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        if (attribute(element, "AXRole") as? String) == "AXTextArea" { return element }
        guard depth < 6, let children = attribute(element, "AXChildren") as? [AXUIElement] else { return nil }
        for child in children {
            if let found = textArea(in: child, depth: depth + 1) { return found }
        }
        return nil
    }

    /// 只往空白便笺里写，避免覆盖已有内容
    static func write(_ text: String, into window: AXUIElement) -> Bool {
        guard let area = textArea(in: window) else { return false }
        let current = (attribute(area, "AXValue") as? String) ?? ""
        guard current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        let wrote = set(area, "AXSelectedText", text as CFString) || set(area, "AXValue", text as CFString)
        let after = (attribute(area, "AXValue") as? String) ?? ""
        let probe = String(text.prefix { $0 != "\n" }.prefix(10))
        return wrote && after.contains(probe)
    }

    static func fillBlankNote(pid: pid_t, text: String) -> Bool {
        for window in windows(pid) where write(text, into: window) { return true }
        return false
    }

    /// 在便笺的菜单里找 ⌘N（新建便笺），不依赖界面语言
    static func newNoteItem(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        if (attribute(element, "AXRole") as? String) == "AXMenuItem",
           (attribute(element, "AXMenuItemCmdChar") as? String)?.uppercased() == "N",
           ((attribute(element, "AXMenuItemCmdModifiers") as? Int) ?? -1) == 0 {
            return element
        }
        guard depth < 4, let children = attribute(element, "AXChildren") as? [AXUIElement] else { return nil }
        for child in children {
            if let found = newNoteItem(in: child, depth: depth + 1) { return found }
        }
        return nil
    }

    static func pressNewNote(_ pid: pid_t) -> Bool {
        guard let raw = attribute(AXUIElementCreateApplication(pid), "AXMenuBar") else { return false }
        let menuBar = raw as! AXUIElement
        guard let item = newNoteItem(in: menuBar) else { return false }
        return AXUIElementPerformAction(item, "AXPress" as CFString) == .success
    }

    static func waitForNewWindow(_ pid: pid_t, excluding before: [AXUIElement], timeout: TimeInterval) -> AXUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for window in windows(pid) where !before.contains(where: { CFEqual($0, window) }) {
                return window
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }
}

// MARK: - 收件箱

final class Inbox {
    let url: URL
    var archiveURL: URL { url.appendingPathComponent(archiveFolderName, isDirectory: true) }
    private var failures: [String: Int] = [:]       // 新建便笺失败次数
    private var readFailures: [String: Int] = [:]   // 读取失败次数（等待 iCloud 下载时会一直重试）
    private var finished: Set<String> = []   // 归档失败时，记住已贴过的文件，避免重复贴
    private var busy = false
    private var warnedMissingFolder = false

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

    func scan() {
        guard !busy else { return }
        busy = true
        defer { busy = false }

        prepare()
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .creationDateKey]
        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys) else { return }

        var pending: [(url: URL, created: Date)] = []
        for item in items {
            let name = item.lastPathComponent
            if name.hasPrefix(".") {
                if name.hasSuffix(".icloud") { requestDownload(placeholder: item) }
                continue
            }
            let values = try? item.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true { continue }
            guard acceptedExtensions.contains(item.pathExtension.lowercased()) else { continue }
            pending.append((item, values?.creationDate ?? .distantPast))
        }

        for entry in pending.sorted(by: { $0.created < $1.created }) {
            handle(entry.url, created: entry.created)
        }
    }

    private func handle(_ file: URL, created: Date) {
        let key = "\(file.lastPathComponent)|\(created.timeIntervalSince1970)"
        if finished.contains(key) { return }
        if let count = failures[key], count >= 5 { return }

        let text: String
        switch readText(file) {
        case .success(let value):
            text = value
            readFailures[key] = nil
        case .failure(let error):
            let n = (readFailures[key] ?? 0) + 1
            readFailures[key] = n
            if n == 1 || n % 30 == 0 {
                logLine("读不到内容（第 \(n) 次，已请求 iCloud 下载）：\(file.lastPathComponent) · \(describe(error))")
            }
            if n == 1 || n % 15 == 0 { requestDownload(of: file) }
            return
        }

        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            archive(file, key: key)
            return
        }

        if StickyMaker.make(content) {
            logLine("已贴到便笺：\(file.lastPathComponent)")
            failures[key] = nil
            archive(file, key: key)
        } else {
            failures[key, default: 0] += 1
            logLine("新建便笺失败（第 \(failures[key] ?? 0) 次）：\(file.lastPathComponent)")
        }
    }

    private func readText(_ file: URL) -> Result<String, Error> {
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
        } catch {
            finished.insert(key)
            logLine("归档失败（不会重复贴）：\(file.lastPathComponent) · \(error.localizedDescription)")
        }
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

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    let inbox = Inbox(url: inboxURL)
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        trimLogIfNeeded()
        logLine("启动 v\(appVersion)，收件箱：\(inbox.url.path)")
        checkAccessibility()
        if materializeResult != 0 { logLine("提示：无法开启 iCloud 按需下载（返回 \(materializeResult)），改用主动下载") }
        inbox.prepare()
        inbox.scan()

        let timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(tick),
                                         userInfo: nil, repeats: true)
        timer.tolerance = 0.5
        self.timer = timer

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(tick), name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc func tick() { inbox.scan() }

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
