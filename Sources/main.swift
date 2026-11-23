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

let appVersion = "0.3.0"
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
        var ok = false
        // 便笺没在运行时，一启动就会自带一张空白便笺。有辅助功能权限时，直接把内容写进这张，避免多出空白的一张。
        if !isStickiesRunning, AXIsProcessTrusted() {
            ok = viaLaunchNote(text)
        }
        if !ok { ok = viaService(text) || viaUIScripting(text) }
        if ok, restoreFocus { giveFocusBack(to: previous) }
        return ok
    }

    static var isStickiesRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: stickiesBundleID).isEmpty
    }

    /// 启动便笺，等它自动生成的空白便笺出现，把文字写进去。找不到空白便笺就返回 false，交给系统服务。
    static func viaLaunchNote(_ text: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: stickiesBundleID) else { return false }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())

        var pid: pid_t = 0
        let deadline = Date().addingTimeInterval(6)
        while Date() < deadline {
            if let running = NSRunningApplication.runningApplications(withBundleIdentifier: stickiesBundleID).first,
               running.isFinishedLaunching {
                pid = running.processIdentifier
                if !StickiesAX.windows(pid).isEmpty { break }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        guard pid != 0 else { return false }
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        if StickiesAX.fillBlankNote(pid: pid, text: text) {
            logLine("便笺刚启动，已写进它自带的空白便笺")
            return true
        }
        return false
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

    /// 新版 macOS（14+）只允许「当前在前台的 App」把焦点让给别人。
    /// 做法：先让自己短暂到前台（没有窗口，看不到），再把焦点让回原来的 App。
    static func giveFocusBack(to app: NSRunningApplication?) {
        guard let app, !app.isTerminated,
              !neverRefocus.contains(app.bundleIdentifier ?? ""),
              app.processIdentifier != getpid() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { return }
            NSApp.activate(ignoringOtherApps: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                if #available(macOS 14.0, *) {
                    NSApp.yieldActivation(to: app)
                    _ = app.activate(from: NSRunningApplication.current, options: [])
                } else {
                    _ = app.activate(options: [.activateIgnoringOtherApps])
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let front = NSWorkspace.shared.frontmostApplication
                    if front?.processIdentifier != app.processIdentifier {
                        logLine("焦点没能还给「\(app.localizedName ?? "原来的 App")」，当前前台：\(front?.localizedName ?? "未知")")
                    }
                }
            }
        }
    }
}

// MARK: - 读写便笺窗口（需要辅助功能权限）

enum StickiesAX {
    static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func set(_ element: AXUIElement, _ name: String, _ value: AnyObject) -> Bool {
        AXUIElementSetAttributeValue(element, name as CFString, value) == .success
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

    static func fillBlankNote(pid: pid_t, text: String) -> Bool {
        for window in windows(pid) {
            guard let area = textArea(in: window) else { continue }
            let current = (attribute(area, "AXValue") as? String) ?? ""
            guard current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            _ = set(area, "AXFocused", true as AnyObject)
            let wrote = set(area, "AXSelectedText", text as CFString) || set(area, "AXValue", text as CFString)
            let after = (attribute(area, "AXValue") as? String) ?? ""
            if wrote, after.contains(String(text.prefix(20))) { return true }
        }
        return false
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

    /// 未授权时，每个新版本只弹一次系统授权提示，不反复打扰。
    func checkAccessibility() {
        if AXIsProcessTrusted() {
            logLine("辅助功能：已授权")
            return
        }
        logLine("辅助功能：未授权（便笺没打开时，可能会多出一张空白便笺）")
        let executable = Bundle.main.executablePath ?? ""
        let modified = (try? FileManager.default.attributesOfItem(atPath: executable)[.modificationDate] as? Date) ?? Date()
        let stamp = String(Int(modified.timeIntervalSince1970))
        if settings.string(forKey: "AXPromptedBuild") != stamp {
            settings.set(stamp, forKey: "AXPromptedBuild")
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
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
    RunLoop.main.run(until: Date().addingTimeInterval(2))
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
