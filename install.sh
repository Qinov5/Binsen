#!/bin/zsh
# Binsen · 安装、更新、设为自启、端到端自检（可重复运行，用于更新）
#
#   一行安装，不用 Xcode，也不用编译（下载打包好的版本）：
#     curl -fsSL https://raw.githubusercontent.com/Qinov5/Binsen/main/install.sh | zsh
#   在项目目录里从源码编译安装：
#     zsh install.sh
#   在项目目录里也想用打包好的版本：
#     zsh install.sh --download

HERE=${0:A:h}

# 整个流程放在函数里：通过 curl 管道运行时，要等脚本完整下载后才开始执行
main() {
set -eu
setopt pipefail

NAME=Binsen
ID=io.github.qinov5.binsen
REPO=Qinov5/Binsen
APP="$HOME/Applications/$NAME.app"
BIN="$APP/Contents/MacOS/$NAME"
SHORTCUTS_ICLOUD="$HOME/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents"
INBOX="$SHORTCUTS_ICLOUD/Binsen"
AGENT="$HOME/Library/LaunchAgents/$ID.plist"
DOMAIN="gui/$(id -u)"
LOG="$HOME/Library/Logs/Binsen.log"
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
WORK=""

step() { print -P "\n%B$1%b" }
ok()   { print -P "%F{green}✓%f $1" }
warn() { print -P "%F{yellow}!%f $1" }
fail() { print -P "%F{red}✗%f $1"; exit 1 }

# 看刚才那张便笺是不是直接写进去的（能控制「便笺」），焦点有没有还给终端
check_paste_path() {
  if tail -15 "$LOG" 2>/dev/null | grep -q -e "已通过便笺菜单新建并写入" -e "已写进便笺启动时自带的空白便笺"; then
    ok "已直接写进便笺：不抢焦点，也不会多出空白便笺"
  else
    warn "Binsen 还不能控制「便笺」，所以用了备用方式（会把便笺调到前台，便笺没打开时可能多一张空白便笺）。"
    print "  授权方法：在弹出的窗口里点 Choose Apps，只添加「便笺 / Stickies」，右边选 At Any Time；"
    print "  或到 系统设置 → 隐私与安全性 → System & App Protection Override（旧版系统叫「辅助功能」）里给 Binsen 授权。授权后重跑本脚本。"
    open "x-apple.systempreferences:com.apple.preference.security" 2>/dev/null || true
  fi
  sleep 2.5
  local front
  front=$(lsappinfo info -only bundleid "$(lsappinfo front)" 2>/dev/null || true)
  if [[ "$front" == *com.apple.Stickies* ]]; then
    warn "焦点停在了便笺上，没能还给终端。授权 Binsen 控制「便笺」后就不会再抢焦点。日志：$LOG"
  else
    ok "焦点已还给终端"
  fi
}

step "1/6 准备 Binsen.app"
if [[ -f "$HERE/Sources/main.swift" && " $* " != *" --download "* ]]; then
  # 从源码编译
  xcrun --find swiftc >/dev/null 2>&1 || fail "找不到 Swift 编译器。先运行 xcode-select --install，或者改用打包好的版本：zsh install.sh --download"
  BUILD="$HERE/build/$NAME.app"
  rm -rf "$HERE/build"
  mkdir -p "$BUILD/Contents/MacOS" "$BUILD/Contents/Resources"
  xcrun swiftc -O -swift-version 5 -o "$BUILD/Contents/MacOS/$NAME" "$HERE/Sources/main.swift"
  cp "$HERE/Info.plist" "$BUILD/Contents/Info.plist"
  # 图标：macOS 26 起，边缘不够实的图标会被系统套上灰框，所以新系统用不透明的全出血版（由系统裁成圆角），旧系统用自带圆角和阴影的版本
  if (( MAJOR >= 26 )); then ICON=AppIcon.icns; else ICON=AppIcon-legacy.icns; fi
  cp "$HERE/Icon/$ICON" "$BUILD/Contents/Resources/AppIcon.icns"
  # 有开发者证书就用证书签名：以后更新时「辅助功能」授权不会失效；没有就用临时签名
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')
  if [[ -n "$IDENTITY" ]] && codesign --force --sign "$IDENTITY" --identifier "$ID" "$BUILD" >/dev/null 2>&1; then
    SIGNED="开发者证书签名，更新后辅助功能授权会保留"
  else
    codesign --force --sign - --identifier "$ID" "$BUILD" >/dev/null 2>&1
    SIGNED="临时签名，每次更新后需要重新打开辅助功能开关"
  fi
else
  # 下载 GitHub Releases 里打包好的版本（Apple 芯片和 Intel 通用）
  if (( MAJOR >= 26 )); then ASSET=Binsen.zip; else ASSET=Binsen-legacy.zip; fi
  URL="https://github.com/$REPO/releases/latest/download/$ASSET"
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/binsen.XXXXXX")
  print "  下载 $URL"
  curl -fL --retry 3 --progress-bar -o "$WORK/$ASSET" "$URL" \
    || fail "下载失败。刚发布的新版本可能还在打包，过几分钟再试；也可以到 https://github.com/$REPO/releases 查看。"
  ditto -x -k "$WORK/$ASSET" "$WORK" || fail "解压失败：$WORK/$ASSET"
  BUILD="$WORK/$NAME.app"
  codesign --verify --deep --strict "$BUILD" >/dev/null 2>&1 || fail "下载的 Binsen.app 没通过签名校验，已停止安装。"
  AUTHORITY=$(codesign -dv "$BUILD" 2>&1 | awk -F= '/^Authority=/ {print $2; exit}')
  if [[ -n "$AUTHORITY" ]]; then
    SIGNED="$AUTHORITY"
  else
    SIGNED="临时签名，每次更新后需要重新打开辅助功能开关"
  fi
fi
ok "$("$BUILD/Contents/MacOS/$NAME" --version) · $SIGNED"

step "2/6 安装到 ~/Applications"
launchctl bootout "$DOMAIN/$ID" 2>/dev/null || true
pkill -x "$NAME" 2>/dev/null || true
sleep 0.5
mkdir -p "$HOME/Applications"
rm -rf "$APP"
ditto "$BUILD" "$APP"
[[ -n "$WORK" ]] && rm -rf "$WORK"
# 让访达、启动台和 App 列表换上新图标
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" >/dev/null 2>&1 || true
ok "$APP"

step "3/6 准备 iCloud 云盘收件箱（旧版「存储文件」捷径用）"
FILES_CHANNEL=1
if [[ ! -d "$SHORTCUTS_ICLOUD" ]]; then
  FILES_CHANNEL=0
  warn "没找到 iCloud 云盘里的「快捷指令」文件夹，先跳过。只影响旧版「存储文件」捷径，提醒事项通道照常可用。"
elif mkdir -p "$INBOX/已处理" 2>/dev/null; then
  ok "iCloud 云盘 › 快捷指令 › Binsen"
else
  FILES_CHANNEL=0
  warn "无法在 iCloud 云盘里创建 $INBOX，先跳过。只影响旧版「存储文件」捷径。"
fi

step "4/6 设为登录后自动运行"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>$ID</string>
	<key>Program</key><string>$BIN</string>
	<key>RunAtLoad</key><true/>
	<key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
	<key>LimitLoadToSessionType</key><string>Aqua</string>
	<key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST
plutil -lint "$AGENT" >/dev/null || fail "LaunchAgent 配置无效：$AGENT"
launchctl bootstrap "$DOMAIN" "$AGENT" 2>/dev/null || { sleep 1; launchctl bootstrap "$DOMAIN" "$AGENT"; }
sleep 1.5
if launchctl print "$DOMAIN/$ID" 2>/dev/null | grep -q "state = running"; then
  ok "后台已运行（登录后自动启动）"
else
  fail "后台进程没起来。查看：launchctl print $DOMAIN/$ID ；日志：$LOG"
fi

step "5/6 自检：iCloud 云盘通道（模拟 iPhone 存入一个文件）"
if (( FILES_CHANNEL )); then
  TEST="$INBOX/安装自检-$(date +%H%M%S).txt"
  print -r -- "Binsen 已接通 ✅  $(date '+%m-%d %H:%M')" > "$TEST"
  for i in {1..15}; do
    [[ -e "$TEST" ]] || break
    sleep 1
  done

  if [[ -e "$TEST" ]]; then
    print "\n收件箱 15 秒内没被处理，单独测一下新建便笺…"
    if "$BIN" --test "Binsen 自检：新建便笺正常"; then
      fail "新建便笺没问题，但后台没处理收件箱，多半是 iCloud 文件夹的访问权限。最近日志：\n$(tail -5 "$LOG" 2>/dev/null)"
    else
      fail "新建便笺失败。请到 系统设置 → 隐私与安全性 → 辅助功能，允许 Binsen，然后重跑本脚本。最近日志：\n$(tail -5 "$LOG" 2>/dev/null)"
    fi
  fi

  ok "便笺里多了一张「Binsen 已接通 ✅」，这张可以直接删掉。"
  check_paste_path
else
  print "  跳过：没有 iCloud 云盘收件箱。"
fi

step "6/6 自检：提醒事项通道"
print "  第一次会弹窗请求访问「提醒事项」，请点「允许」（90 秒内）。"
REMIND="Binsen 提醒事项通道已接通 ✅  $(date '+%m-%d %H:%M')"
if "$BIN" --remind "$REMIND" >/dev/null 2>&1; then
  for i in {1..20}; do
    tail -8 "$LOG" 2>/dev/null | grep -q "已贴到便笺：提醒事项「Binsen 提醒事项通道已接通" && break
    sleep 1
  done
  if tail -8 "$LOG" 2>/dev/null | grep -q "已贴到便笺：提醒事项「Binsen 提醒事项通道已接通"; then
    ok "便笺里又多了一张「Binsen 提醒事项通道已接通 ✅」，也可以删掉。"
    (( FILES_CHANNEL )) || check_paste_path
  else
    warn "已往提醒事项列表「Binsen」里加了一条，但 20 秒内没贴出来。先看日志：tail -20 $LOG"
  fi
else
  warn "提醒事项通道还没开：到 系统设置 → 隐私与安全性 → 提醒事项，打开 Binsen，然后重跑本脚本。"
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders" 2>/dev/null || true
fi

print "\n下一步：在 iPhone 上设置快捷指令，步骤见 https://github.com/$REPO"
}

main "$@"
