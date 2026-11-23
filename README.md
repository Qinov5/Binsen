# Binsen

在 iPhone 上写一句，几秒后 Mac 自带的「便笺」(Stickies) 里多一张。

名字来自日语「便箋（びんせん）」，意思就是便笺。

[English](#english)

```
iPhone 快捷指令「Binsen」
   └─ 存成 .txt → iCloud 云盘 › 快捷指令 › Binsen
                      └─ Mac 后台 Binsen 发现新文件
                             └─ 在便笺里新建一张，写入文字
                             └─ 原文件移到 Binsen/已处理
```

- 用的是 macOS 自带的便笺，不是仿制的浮窗。
- 便笺不会被调到前台，正在 Mac 上打字不会被打断；便笺没打开时也不会多出空白便笺（需要允许 Binsen 控制「便笺」）。
- 不动剪贴板。
- 不需要服务器、账号或网络端口，只靠 iCloud 云盘同步。
- 单个 Swift 文件，没有第三方依赖。

## 要求

- macOS 13 或更新版本
- Xcode 或命令行工具（`xcode-select --install`）
- Mac 和 iPhone 登录同一个 Apple 账户，并打开 iCloud 云盘

## 权限

推荐允许 Binsen 控制「便笺」这一个 App（不需要控制其他 App）。授权后，Binsen 会通过便笺自己的「新建便笺」菜单建一张再写入：

- 便笺不会被调到前台，正在 Mac 上打字也不会被打断；
- 便笺没打开时，直接写进它启动时自带的那张空白便笺，不会多出一张空白的。

| 系统版本 | 在哪里授权 |
|---|---|
| macOS 27.3 及以后 | 弹窗里点 **Choose Apps**，只添加「便笺」，并把它右边改成 **At Any Time**（选 Ask First 的话每次都会弹窗确认）；之后也可以在 系统设置 → 隐私与安全性 → System & App Protection Override 里修改 |
| 更早的版本 | 系统设置 → 隐私与安全性 → 辅助功能（macOS 27 早期版本叫 Device Control and Data Access），打开 Binsen |

不授权也能用：会改用系统服务新建便笺，此时便笺会被调到前台，便笺没打开时可能多出一张空白便笺。

安装脚本会优先用钥匙串里的开发者证书（Apple Development）签名，这样以后更新时授权不会失效；第一次签名时 macOS 可能会询问是否允许 codesign 使用钥匙串，选「始终允许」即可。没有证书时用临时签名，每次更新后需要重新授权一次。

## Mac 端安装

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

脚本会：编译 → 装到 `~/Applications/Binsen.app` → 在 iCloud 里建收件箱 → 设为登录后自动运行 → 放一条测试进收件箱。便笺里出现「Binsen 已接通 ✅」就说明装好了。

更新：`git pull && zsh install.sh`

## iPhone 端：快捷指令「Binsen」

在 iPhone 上点开链接，选「添加快捷指令」：

### [添加快捷指令 Binsen](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)

它只做两件事：让你输入一段文字，存到 iCloud 云盘 › 快捷指令 › Binsen。添加后运行一次，写一句试试。

想按一下就能写：设置 → 操作按钮 → 快捷指令 → Binsen（适用于有操作按钮的 iPhone）。

<details>
<summary>自己动手建</summary>

1. 快捷指令 App → 右上角 ＋，命名「Binsen」。
2. 添加操作 **要求输入**，类型选「文本」。
3. 添加操作 **存储文件**：
   - 存储的内容选「提供的输入」
   - 关闭「询问存储位置」
   - 子路径填 `/Binsen/`

也可以在 Mac 的快捷指令 App 里建，会通过 iCloud 同步到 iPhone。

</details>

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
| 日志说「没有控制便笺的权限」 | 见上面「权限」一节 |
| 新便笺出现后焦点没回到原来的 App | 先确认已授权 Binsen 控制「便笺」；仍有问题，把日志里「焦点没能还给…」那行发到 Issues |
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
- 读到内容后，通过辅助功能按下便笺菜单里的「新建便笺」（⌘N），再把文字写进这张新便笺；便笺不会被激活，所以不抢焦点。
- 便笺当时没在运行：在后台启动它，把文字写进它启动时自带的空白便笺。
- 没有控制「便笺」的权限时，改用系统服务 `NSPerformService("Make Sticky", …)`，再尽量把焦点交还原来的 App。

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

**How it works.** An iPhone Shortcut saves your text as a `.txt` file into `iCloud Drive/Shortcuts/Binsen`. A small background app on the Mac watches that folder, creates a new sticky, then moves the file into `已处理` (processed). No server, no account, no open ports.

**Requirements.** macOS 13+, Xcode or Command Line Tools, iCloud Drive on both devices.

**Install (Mac).**

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

The script builds the app, installs it to `~/Applications`, creates the inbox folder, registers a LaunchAgent, and runs an end-to-end self-test.

**iPhone Shortcut.** Open **[Add the Binsen shortcut](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)** on your iPhone and tap *Add Shortcut*.

Or build it yourself with two actions:

1. **Ask for Input** (Text)
2. **Save File** — input: *Provided Input*, turn off *Ask Where to Save*, Subpath: `/Binsen/`

**Logs:** `~/Library/Logs/Binsen.log` · **Uninstall:** `zsh uninstall.sh`

**Permission (recommended).** Allow Binsen to control the Stickies app only (macOS 27.3+: click *Choose Apps*, add Stickies and set it to *At Any Time*; earlier versions: Privacy & Security → Accessibility). Binsen then creates the note through Stickies' own *New Note* menu and types into it, so Stickies never steals focus and no blank note is left behind when Stickies wasn't running. Without it, Binsen falls back to the `Make Sticky` service.

## License

[MIT](LICENSE)
