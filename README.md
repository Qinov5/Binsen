# Binsen（便箋）

**简体中文** | [English](README.en.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [Español](README.es.md)

在 iPhone 上随手记下一句，几秒后，Mac 桌面的原生「便笺」(Stickies) 里就会安静地多出一张。

https://github.com/user-attachments/assets/12b98983-d6f9-4837-83bc-dde8d83b0335

**Binsen** 取自日语「便箋（びんせん）」，意为信笺、便笺。出门在外闪现的念头、临时待办或零碎摘录，不必再发给「文件传输助手」，也不用点开厚重的笔记软件——回到电脑前，它已经贴在桌面上等你了。

```text
iPhone 快捷指令「Binsen」
  ├─ 推荐：添加到提醒事项列表「Binsen」 ──▶ iCloud，几秒同步
  └─ 旧版：存为 .txt ──▶ iCloud 云盘/快捷指令/Binsen
                        └─ Mac 后台常驻的 Binsen 收到新内容
                              ├─ 静默在「便笺」中新建一页并写入内容
                              └─ 提醒事项标记为已完成；文件归档至 Binsen/已处理（30 天后自动删除）
```

## 为什么做它

* **纯正原生**：直接写入 macOS 自带的「便笺」App，不是第三方仿制浮窗。
* **零打扰写入**：全程后台操作，不抢占当前窗口焦点，在 Mac 上打字不会被突然打断；新便笺从屏幕右上角依次往下排，不会盖住已有的便笺；若「便笺」尚未运行，会自动复用它启动时自带的默认空白页，绝不多留一张废纸。
* **干净无痕**：完全不读写、不污染系统剪贴板；贴出后的原文 30 天后自动从 iCloud 删除。
* **零外部依赖**：无需服务器、无需注册账号、不开放任何网络端口，只用你自己的 iCloud（提醒事项或 iCloud 云盘）同步。
* **极简透明**：核心逻辑仅单个 Swift 文件，无任何第三方依赖，代码一眼到底。

## 环境要求

* macOS 13 或更新版本（Apple 芯片和 Intel 均可）
* Mac 与 iPhone 登录同一个 Apple 账户，并在 iCloud 中开启 **提醒事项**（使用旧版文件方式时还需开启 **iCloud 云盘**）

## 快速开始

### 1. Mac 端安装

打开「终端」，粘贴下面这一行并回车：

```bash
curl -fsSL https://raw.githubusercontent.com/Qinov5/Binsen/main/install.sh | zsh
```

不用装 Xcode，也不用编译。安装脚本会自动完成：**下载打包好的 Binsen → 安装至 `~/Applications/Binsen.app` → 创建 iCloud 收件箱目录 → 注册开机自启服务 → 分别自检 iCloud 云盘通道和提醒事项通道**。

看到桌面便笺里跳出 **「Binsen 已接通 ✅」** 和 **「Binsen 提醒事项通道已接通 ✅」**，即代表安装成功。

> **日常更新**：再运行一次上面这行命令即可覆盖更新。
>
> **关于签名**：下载的安装包是临时签名，每次更新后可能需要重新授权一次（脚本自检时会提示并打开设置页）。
>
> **从源码编译**（需要 Xcode 或命令行工具，`xcode-select --install`）：
> ```bash
> git clone https://github.com/Qinov5/Binsen.git && cd Binsen && zsh install.sh
> ```
> 以后在项目目录执行 `git pull && zsh install.sh` 更新。脚本会优先使用钥匙串中的 `Apple Development` 证书签名（首次运行若询问是否允许 `codesign` 访问钥匙串，选「始终允许」），这样更新后不会丢失系统授权。

### 2. 授予控制权限（强烈推荐）

首次触发自检时，系统会请求控制权限。建议仅允许 Binsen 控制 **「便笺」** 这一个 App——授权后，Binsen 才能通过菜单静默建页、不抢焦点，并消除冷启动时的多余空白页。

| 系统版本 | 授权方式 |
| :--- | :--- |
| **macOS 27.3 及更新版本** | 在弹窗中点击 **Choose Apps**，仅添加「便笺」，并将右侧权限改为 **At Any Time**（若选 *Ask First* 则每次都会弹窗）。后续也可在 `系统设置 → 隐私与安全性 → System & App Protection Override` 中调整。 |
| **更早版本** | 前往 `系统设置 → 隐私与安全性 → 辅助功能`（macOS 27 早期版本名为 *Device Control and Data Access*），开启 **Binsen**。 |

*注：不授权同样可用。此时程序会自动降级调用系统服务（Make Sticky）创建便笺，但新建时会将「便笺」调至前台，且便笺未运行时可能会多出一张空白页。*

**提醒事项权限**：安装过程中会弹窗请求访问「提醒事项」，请点「允许」。Binsen 只读写「Binsen」这一个列表（没有会自动在 iCloud 里新建），贴成便笺后会把那条提醒事项标记为已完成。如果漏点了，到 `系统设置 → 隐私与安全性 → 提醒事项` 打开 Binsen，再重新运行一次安装命令。

### 3. iPhone 端配置快捷指令

推荐使用「提醒事项」版：提醒事项会立即同步，实测从 iPhone 发出到 Mac 贴出约 10 秒。

👉 **[点击添加快捷指令「Binsen」](https://www.icloud.com/shortcuts/54ba2387d2b54ceebe1437aef3b34d47)**

它只做两件极简的事：唤起文本输入框 → 把内容添加到提醒事项列表「Binsen」。添加后打开看一眼：如果列表一栏不是「Binsen」，重新选一下即可（先在 Mac 上装好 Binsen，这个列表会自动出现）。

💡 **顺手技巧**：如果你的 iPhone 带有「操作按钮」(Action Button)，可前往 `设置 → 操作按钮 → 快捷指令` 选择 **Binsen**，以后按一下侧边键就能随手贴便笺。你也可以将其添加到锁屏小组件或轻点背面触发。

<details>
<summary>不想点链接？三步手动创建</summary>

1. 打开「快捷指令」App，点击右上角 **＋**，命名为 `Binsen`。
2. 添加操作 **要求输入**，输入类型选「文本」。
3. 添加操作 **添加新提醒事项**：提醒事项一栏选「提供的输入」（一般会自动填好），列表选 **Binsen**（若暂时没出现，打开一次「提醒事项」App 等它同步）。

*(在 Mac 的快捷指令 App 中创建也可，会自动通过 iCloud 同步至 iPhone。)*
</details>

<details>
<summary>旧版：存成文件到 iCloud 云盘（可能延迟很久）</summary>

👉 [点击添加旧版快捷指令](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)

也可以手动创建：**要求输入**（文本）→ **存储文件**（存储内容选「提供的输入」，关闭「询问存储位置」，子路径填 `/Binsen/`）。

> 注意：iPhone 往往不会马上把快捷指令存下的文件传到 iCloud，常常要等你打开「文件」App 才开始上传，所以可能延迟几分钟到几小时。Mac 端仍会监听这个文件夹，旧捷径可以继续用。
</details>

## 进阶设置

可通过 `defaults` 命令按需调整默认行为：

```bash
# 新建便笺后让「便笺」留在前台（默认会将焦点归还给原窗口）
defaults write io.github.qinov5.binsen RestoreFocus -bool false

# 自定义监听的收件箱目录
defaults write io.github.qinov5.binsen InboxPath "~/某个文件夹"

# 修改提醒事项通道监听的列表（默认 Binsen，没有会自动新建）
defaults write io.github.qinov5.binsen RemindersList "某个列表"

# 关闭提醒事项通道，只用 iCloud 云盘文件
defaults write io.github.qinov5.binsen UseReminders -bool false

# 新便笺的位置：默认从屏幕右上角往下排、不盖住已有便笺；在便笺默认位置依次往右下错开用 cascade，不挪用 off
defaults write io.github.qinov5.binsen NotePlacement cascade

# 已贴出的原文保留几天：到期自动删除「已处理」里的文件和提醒事项里的已完成项（默认 30；0 = 一直保留）
# RemindersList 改成你自己的列表时，只有设置了这一项才会清理那个列表
defaults write io.github.qinov5.binsen KeepDays -int 7

# 修改配置后重启后台服务生效
launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen
```

## 常见问题排查

| 现象 | 排查方式 |
| :--- | :--- |
| 迟迟没出现新便笺 | 查看运行日志：`tail -20 ~/Library/Logs/Binsen.log` |
| 便笺隔了很久才出现 | 看日志里「收到：…」那一行：会写明 iCloud 用了多久才送到这台 Mac、期间 Mac 睡了多久。从「收到」到「已贴到便笺」一般只要 1–2 秒，慢基本都慢在 iCloud 这一段 |
| Mac 合盖或睡眠期间发的便笺没出现 | Mac 睡着时没法新建便笺；唤醒后 iCloud 会补齐同步，通常几十秒内自动贴出 |
| 用旧版（存储文件）捷径时，要打开「文件」App 才会到 | iPhone 不会马上上传快捷指令存下的文件。换成上面的「提醒事项」版捷径即可 |
| Mac 醒着、iPhone 也已发出，仍要等好几分钟 | 多半是 iCloud 推送被代理或 VPN 挡住了，Mac 收不到更新通知。用 Shadowrocket、Clash 等设置了系统代理时，把 `*.push.apple.com` 和 `17.0.0.0/8` 加进「跳过代理」列表 |
| 日志提示「没有控制便笺的权限」 | 参考上方「授予控制权限」一节开启授权 |
| 日志提示「提醒事项：没有访问权限」 | 到 `系统设置 → 隐私与安全性 → 提醒事项` 打开 Binsen，再执行 `launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen` |
| 新建便笺后焦点未回到原窗口 | 先确认已完成权限配置；若仍复现，欢迎将日志中 `焦点没能还给…` 所在行贴至 Issues |
| 检查后台服务是否在运行 | 执行 `launchctl print gui/$(id -u)/io.github.qinov5.binsen \| grep state` |

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/Qinov5/Binsen/main/uninstall.sh | zsh
```

（在项目目录里也可以直接运行 `zsh uninstall.sh`。）

卸载脚本仅移除后台应用与自启配置，**iCloud 收件箱文件夹、提醒事项里的「Binsen」列表及桌面已有的全部便笺均会完整保留**。

## 实现原理与目录结构

* **轻量常驻**：`Binsen.app` 作为无程序坞图标的后台应用运行，由 `LaunchAgent` 在登录时拉起；通过 FSEvents 监听收件箱，文件一到立刻处理，另有每 2 秒一次的兜底检查。新建失败会按 2、4、8 …… 秒自动重试，直到贴上为止。
* **提醒事项通道**：通过 EventKit 监听「Binsen」列表的变化（另每分钟主动刷新一次），读到新提醒事项后贴成便笺，再标记为已完成。提醒事项走 CloudKit，iPhone 会立即上传；快捷指令存下的文件则要等 iCloud 云盘择机上传。
* **按需拉取云端文件**：从 iPhone 刚同步过来的 `.txt` 在 Mac 上可能仅是未下载的占位文件。程序通过 `setiopolicy_np` 开启按需下载，遇到未就绪文件还会主动调用 `brctl download` 触发拉取。读取在后台线程进行，某个文件下载得慢，也不会耽误其他便笺。
* **无感注入**：读取文本后，借助辅助功能接口直接触发便笺菜单栏的「新建便笺」（`⌘N`）并填入内容，全程不激活便笺窗口；若便笺未在运行，则静默后台拉起并直接写入其初始空白页；若未获授权，则平滑降级至 `NSPerformService("Make Sticky", …)` 并尽力归还焦点。
* **摆放与清理**：新便笺写好后，借助辅助功能接口挪到屏幕右上角的空位（一列排满往左再起一列，都满了就在右上角依次错开）。贴出后的原文保留 30 天，之后自动从「已处理」文件夹和提醒事项里删除。
* **打包发布**：发布 Release 时，GitHub Actions 编译 Apple 芯片和 Intel 通用版本，打成 Binsen.zip 挂到 Release 上，一行安装命令下载的就是它。

```text
Sources/main.swift           核心监听与写入逻辑（单文件无依赖）
Info.plist                   后台无界面 App 配置
Binsen.entitlements          用 Developer ID 签名、公证时的权限声明
Icon/                        App 图标（AppIcon.svg 为源文件；按系统版本选用 .icns）
install.sh                   下载或编译、安装、自启与端到端自检（支持幂等更新）
uninstall.sh                 清理应用与自启服务
scripts/package.sh           打包发布用的通用安装包
.github/workflows/build.yml  每次推送都编译一遍；发布 Release 时自动挂上安装包
```

## License

[MIT](LICENSE)
