# Binsen

在 iPhone 上写一句，几秒后 Mac 自带的「便笺」(Stickies) 里多一张。

名字来自日语「便箋（びんせん）」，意思就是便笺。

[English](#english)

```
iPhone 快捷指令「Binsen」
   └─ 存成 .txt → iCloud 云盘 › 快捷指令 › Binsen
                      └─ Mac 后台 Binsen 发现新文件
                             └─ 调系统服务新建便笺 → 便笺 App 里出现一张
                             └─ 原文件移到 Binsen/已处理
```

- 用的是 macOS 自带的便笺，不是仿制的浮窗。
- 新建便笺走系统服务（Services → `Make Sticky`），不动剪贴板；服务不可用时才改用 ⌘N + ⌘V。
- 便笺没打开时，直接把内容写进它启动时自带的那张空白便笺，不会多出一张空白的（需要辅助功能权限）。
- 新便笺出现后，会把键盘焦点还给你正在用的 App，打字不会被打断。
- 不需要服务器、账号或网络端口，只靠 iCloud 云盘同步。
- 单个 Swift 文件，没有第三方依赖。

## 要求

- macOS 13 或更新版本
- Xcode 或命令行工具（`xcode-select --install`）
- Mac 和 iPhone 登录同一个 Apple 账户，并打开 iCloud 云盘

## 权限

| 权限 | 用途 | 不开会怎样 |
|---|---|---|
| 辅助功能（推荐） | 便笺没打开时，把内容写进它启动时自带的空白便笺；新便笺出现后把焦点还给原来的 App | 可能多出一张空白便笺；焦点可能停在便笺上 |

首次运行会弹出授权提示；也可以到 系统设置 → 隐私与安全性 → 辅助功能，打开 Binsen。

安装脚本会优先用钥匙串里的开发者证书（Apple Development）签名，这样以后更新时授权不会失效；第一次签名时 macOS 可能会询问是否允许 codesign 使用钥匙串，选「始终允许」即可。没有证书时用临时签名，每次更新后需要在辅助功能里重新打开一次。

## Mac 端安装

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

脚本会：编译 → 装到 `~/Applications/Binsen.app` → 在 iCloud 里建收件箱 → 设为登录后自动运行 → 放一条测试进收件箱。便笺里出现「Binsen 已接通 ✅」就说明装好了。

更新：`git pull && zsh install.sh`

## iPhone 端：快捷指令「Binsen」

1. 快捷指令 App → 右上角 ＋，命名「Binsen」。
2. 添加操作 **要求输入**，类型选「文本」。
3. 添加操作 **存储文件**：
   - 存储的内容选「提供的输入」
   - 关闭「询问存储位置」
   - 子路径填 `/Binsen/`
4. 运行一次，写一句试试。

也可以在 Mac 的快捷指令 App 里建，会通过 iCloud 同步到 iPhone。

想按一下就能写：设置 → 操作按钮 → 快捷指令 → Binsen（适用于有操作按钮的 iPhone）。

## 设置

```bash
# 新建便笺后让便笺留在前台（默认会把焦点还给原来的 App）
defaults write io.github.qinov5.binsen RestoreFocus -bool false

# 换一个收件箱文件夹
defaults write io.github.qinov5.binsen InboxPath "~/某个文件夹"

# 改完重启后台
launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen
```

## 排查

| 现象 | 处理 |
|---|---|
| 一直没出现便笺 | `tail -20 ~/Library/Logs/Binsen.log` |
| iPhone 存了，Mac 收件箱里没文件 | iCloud 同步慢或 Mac 在睡眠；到「访达 › iCloud 云盘 › 快捷指令 › Binsen」看文件到了没有 |
| 日志说需要「辅助功能」 | 系统设置 → 隐私与安全性 → 辅助功能 → 打开 Binsen。重新编译安装后可能要再打开一次 |
| 新便笺出现后焦点没回到原来的 App | 日志里会记一行「焦点没能还给…」，把它发到 Issues |
| 后台是否在运行 | `launchctl print gui/$(id -u)/io.github.qinov5.binsen \| grep state` |

## 卸载

```bash
zsh uninstall.sh
```

收件箱文件夹和已有的便笺都会保留。

## 工作原理

- iPhone 快捷指令把文字存成 `.txt`，放进 iCloud 云盘的「快捷指令」文件夹下的 `Binsen`。
- Mac 上的 `Binsen.app` 是一个不显示在程序坞的后台 App，由 LaunchAgent 在登录时启动，每 2 秒检查一次收件箱。
- 从 iPhone 同步来的文件在 Mac 上可能只是占位（还没下载）。程序用 `setiopolicy_np` 打开按需下载，读不到时再用 `brctl download` 主动请求下载。
- 读到内容后调用 `NSPerformService("Make Sticky", …)`，让便笺 App 新建一张，然后把原文件移到 `已处理`。
- 如果便笺当时没在运行：先启动它，再通过辅助功能把文字写进它自带的空白便笺，而不是另建一张。
- 新便笺出现后，有辅助功能权限时直接把原来的 App 设为前台；没有时退而用 macOS 14 的协作激活（`yieldActivation(to:)`）尝试交还焦点。

## 文件

```
Sources/main.swift   全部逻辑
Info.plist           后台 App 配置
install.sh           编译、安装、自启、自检（可重复运行，用于更新）
uninstall.sh         卸载
```

---

## English

Type a line on your iPhone; a few seconds later it shows up as a new note in the built-in macOS **Stickies** app.

**How it works.** An iPhone Shortcut saves your text as a `.txt` file into `iCloud Drive/Shortcuts/Binsen`. A small background app on the Mac watches that folder, creates a new sticky through the system service `Make Sticky` (no Accessibility permission needed), then moves the file into `已处理` (processed). No server, no account, no open ports.

**Requirements.** macOS 13+, Xcode or Command Line Tools, iCloud Drive on both devices.

**Install (Mac).**

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

The script builds the app, installs it to `~/Applications`, creates the inbox folder, registers a LaunchAgent, and runs an end-to-end self-test.

**iPhone Shortcut.** Create a shortcut with two actions:

1. **Ask for Input** (Text)
2. **Save File** — input: *Provided Input*, turn off *Ask Where to Save*, Subpath: `/Binsen/`

**Logs:** `~/Library/Logs/Binsen.log` · **Uninstall:** `zsh uninstall.sh`

After the sticky appears, keyboard focus is handed back to the app you were using, so typing on the Mac isn't interrupted.

**Accessibility (recommended).** When Stickies isn't running, it opens an empty note on launch. With Accessibility access, Binsen writes your text into that note instead of leaving a blank one behind. Grant it in System Settings → Privacy & Security → Accessibility. If you have an Apple Development certificate, `install.sh` signs with it so the grant survives updates.

## License

[MIT](LICENSE)
