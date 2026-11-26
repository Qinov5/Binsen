# Binsen（便箋）

**简体中文** | [English](README.en.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [Español](README.es.md)

在 iPhone 上随手记下一句，几秒后，Mac 桌面的原生「便笺」(Stickies) 里就会安静地多出一张。

https://github.com/user-attachments/assets/12b98983-d6f9-4837-83bc-dde8d83b0335

**Binsen** 取自日语「便箋（びんせん）」，意为信笺、便笺。出门在外闪现的念头、临时待办或零碎摘录，不必再发给「文件传输助手」，也不用点开厚重的笔记软件——回到电脑前，它已经贴在桌面上等你了。

```text
iPhone 快捷指令「Binsen」
  └─ 存为 .txt ──▶ iCloud 云盘/快捷指令/Binsen
                        └─ Mac 后台守护进程检测新文件
                              ├─ 静默在「便笺」中新建一页并写入内容
                              └─ 原文件归档至 Binsen/已处理
```

## 为什么做它

* **纯正原生**：直接写入 macOS 自带的「便笺」App，不是第三方仿制浮窗。
* **零打扰写入**：全程后台操作，不抢占当前窗口焦点，在 Mac 上打字不会被突然打断；若「便笺」尚未运行，会自动复用它启动时自带的默认空白页，绝不多留一张废纸。
* **干净无痕**：完全不读写、不污染系统剪贴板。
* **零外部依赖**：无需服务器、无需注册账号、不开放任何网络端口，纯靠 iCloud 云盘同步。
* **极简透明**：核心逻辑仅单个 Swift 文件，无任何第三方依赖，代码一眼到底。

## 环境要求

* macOS 13 或更新版本
* Xcode 或命令行工具（可通过 `xcode-select --install` 安装）
* Mac 与 iPhone 登录同一个 Apple 账户，并开启 **iCloud 云盘**

## 快速开始

### 1. Mac 端安装

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

安装脚本会自动完成：**编译构建 → 安装至 `~/Applications/Binsen.app` → 创建 iCloud 收件箱目录 → 注册开机自启服务 → 投递一条自检消息**。

看到桌面便笺里跳出 **「Binsen 已接通 ✅」**，即代表安装成功。

> **日常更新**：在项目目录下执行 `git pull && zsh install.sh` 即可覆盖更新。
>
> **关于签名**：脚本会优先使用钥匙串中的 `Apple Development` 证书签名（首次运行时若系统询问是否允许 `codesign` 访问钥匙串，选择「始终允许」即可），这样后续更新不会丢失系统授权；若无开发者证书则会采用临时签名，每次更新后需重新授权一次。

### 2. 授予控制权限（强烈推荐）

首次触发自检时，系统会请求控制权限。建议仅允许 Binsen 控制 **「便笺」** 这一个 App——授权后，Binsen 才能通过菜单静默建页、不抢焦点，并消除冷启动时的多余空白页。

| 系统版本 | 授权方式 |
| :--- | :--- |
| **macOS 27.3 及更新版本** | 在弹窗中点击 **Choose Apps**，仅添加「便笺」，并将右侧权限改为 **At Any Time**（若选 *Ask First* 则每次都会弹窗）。后续也可在 `系统设置 → 隐私与安全性 → System & App Protection Override` 中调整。 |
| **更早版本** | 前往 `系统设置 → 隐私与安全性 → 辅助功能`（macOS 27 早期版本名为 *Device Control and Data Access*），开启 **Binsen**。 |

*注：不授权同样可用。此时程序会自动降级调用系统服务（Make Sticky）创建便笺，但新建时会将「便笺」调至前台，且便笺未运行时可能会多出一张空白页。*

### 3. iPhone 端配置快捷指令

在 iPhone 上点击下方链接添加现成的快捷指令：

👉 **[点击添加快捷指令「Binsen」](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)**

它只做两件极简的事：唤起文本输入框 → 将内容存入 `iCloud 云盘 › 快捷指令 › Binsen`。添加后点一下，写句话试试看。

💡 **顺手技巧**：如果你的 iPhone 带有「操作按钮」(Action Button)，可前往 `设置 → 操作按钮 → 快捷指令` 选择 **Binsen**，以后按一下侧边键就能随手贴便笺。你也可以将其添加到锁屏小组件或轻点背面触发。

<details>
<summary>不想点链接？两步手动创建</summary>

1. 打开「快捷指令」App，点击右上角 **＋**，命名为 `Binsen`。
2. 添加操作 **要求输入**，输入类型选「文本」。
3. 添加操作 **存储文件**：
   * 存储内容选择「提供的输入」
   * **关闭**「询问存储位置」
   * 子路径填写 `/Binsen/`

*(在 Mac 的快捷指令 App 中创建也可，会自动通过 iCloud 同步至 iPhone。)*
</details>

## 进阶设置

可通过 `defaults` 命令按需调整默认行为：

```bash
# 新建便笺后让「便笺」留在前台（默认会将焦点归还给原窗口）
defaults write io.github.qinov5.binsen RestoreFocus -bool false

# 自定义监听的收件箱目录
defaults write io.github.qinov5.binsen InboxPath "~/某个文件夹"

# 修改配置后重启后台服务生效
launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen
```

## 常见问题排查

| 现象 | 排查方式 |
| :--- | :--- |
| 迟迟没出现新便笺 | 查看运行日志：`tail -20 ~/Library/Logs/Binsen.log` |
| iPhone 已保存，但 Mac 收件箱为空 | 通常是 iCloud 同步延迟或 Mac 处于休眠状态；可前往 `访达 › iCloud 云盘 › 快捷指令 › Binsen` 查看文件是否到达 |
| 日志提示「没有控制便笺的权限」 | 参考上方「授予控制权限」一节开启授权 |
| 新建便笺后焦点未回到原窗口 | 先确认已完成权限配置；若仍复现，欢迎将日志中 `焦点没能还给…` 所在行贴至 Issues |
| 检查后台服务是否在运行 | 执行 `launchctl print gui/$(id -u)/io.github.qinov5.binsen \| grep state` |

## 卸载

```bash
zsh uninstall.sh
```

卸载脚本仅移除后台应用与自启配置，**iCloud 收件箱文件夹及桌面已有的全部便笺均会完整保留**。

## 实现原理与目录结构

* **轻量常驻**：`Binsen.app` 作为无程序坞图标的后台应用运行，由 `LaunchAgent` 在登录时拉起，每 2 秒轮询一次收件箱目录。
* **按需拉取云端文件**：从 iPhone 刚同步过来的 `.txt` 在 Mac 上可能仅是未下载的占位文件。程序通过 `setiopolicy_np` 开启按需下载，遇到未就绪文件还会主动调用 `brctl download` 触发拉取。
* **无感注入**：读取文本后，借助辅助功能接口直接触发便笺菜单栏的「新建便笺」（`⌘N`）并填入内容，全程不激活便笺窗口；若便笺未在运行，则静默后台拉起并直接写入其初始空白页；若未获授权，则平滑降级至 `NSPerformService("Make Sticky", …)` 并尽力归还焦点。

```text
Sources/main.swift   核心监听与写入逻辑（单文件无依赖）
Info.plist           后台无界面 App 配置
Icon/                App 图标（AppIcon.svg 为源文件；安装时按系统版本选用 .icns）
install.sh           编译、签名、安装、自启与端到端自检（支持幂等更新）
uninstall.sh         清理应用与自启服务
```

## License

[MIT](LICENSE)
