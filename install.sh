#!/bin/zsh
# Binsen · 编译、安装、设为自启、端到端自检
# 用法：zsh install.sh   （可重复运行，用于更新）
set -eu
setopt pipefail

HERE=${0:A:h}
NAME=Binsen
ID=io.github.qinov5.binsen
APP="$HOME/Applications/$NAME.app"
BIN="$APP/Contents/MacOS/$NAME"
SHORTCUTS_ICLOUD="$HOME/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents"
INBOX="$SHORTCUTS_ICLOUD/Binsen"
AGENT="$HOME/Library/LaunchAgents/$ID.plist"
DOMAIN="gui/$(id -u)"
LOG="$HOME/Library/Logs/Binsen.log"

step() { print -P "\n%B$1%b" }
ok()   { print -P "%F{green}✓%f $1" }
fail() { print -P "%F{red}✗%f $1"; exit 1 }

step "1/5 编译"
xcrun --find swiftc >/dev/null 2>&1 || fail "找不到 Swift 编译器，先运行：xcode-select --install"
BUILD="$HERE/build/$NAME.app"
rm -rf "$HERE/build"
mkdir -p "$BUILD/Contents/MacOS"
xcrun swiftc -O -swift-version 5 -o "$BUILD/Contents/MacOS/$NAME" "$HERE/Sources/main.swift"
cp "$HERE/Info.plist" "$BUILD/Contents/Info.plist"
# 有开发者证书就用证书签名：以后更新时「辅助功能」授权不会失效；没有就用临时签名
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')
if [[ -n "$IDENTITY" ]] && codesign --force --sign "$IDENTITY" --identifier "$ID" "$BUILD" >/dev/null 2>&1; then
  SIGNED="开发者证书签名，更新后辅助功能授权会保留"
else
  codesign --force --sign - --identifier "$ID" "$BUILD" >/dev/null 2>&1
  SIGNED="临时签名，每次更新后需要重新打开辅助功能开关"
fi
ok "$("$BUILD/Contents/MacOS/$NAME" --version) · $SIGNED"

step "2/5 安装到 ~/Applications"
launchctl bootout "$DOMAIN/$ID" 2>/dev/null || true
pkill -x "$NAME" 2>/dev/null || true
sleep 0.5
mkdir -p "$HOME/Applications"
rm -rf "$APP"
cp -R "$BUILD" "$APP"
ok "$APP"

step "3/5 准备 iCloud 收件箱"
[[ -d "$SHORTCUTS_ICLOUD" ]] || fail "没找到 iCloud 云盘里的「快捷指令」文件夹。请确认 iCloud 云盘已开启，并在 iPhone 上打开过一次快捷指令。"
mkdir -p "$INBOX/已处理" || fail "无法在 iCloud 云盘里创建：$INBOX"
ok "iCloud 云盘 › 快捷指令 › Binsen"

step "4/5 设为登录后自动运行"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$AGENT" <<EOF
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
EOF
plutil -lint "$AGENT" >/dev/null || fail "LaunchAgent 配置无效：$AGENT"
launchctl bootstrap "$DOMAIN" "$AGENT" 2>/dev/null || { sleep 1; launchctl bootstrap "$DOMAIN" "$AGENT"; }
sleep 1.5
if launchctl print "$DOMAIN/$ID" 2>/dev/null | grep -q "state = running"; then
  ok "后台已运行（登录后自动启动）"
else
  fail "后台进程没起来。查看：launchctl print $DOMAIN/$ID ；日志：$LOG"
fi
if tail -5 "$LOG" 2>/dev/null | grep -q "辅助功能：已授权"; then
  ok "辅助功能已授权"
else
  print -P "%F{yellow}!%f 建议打开「辅助功能」：系统设置 → 隐私与安全性 → 辅助功能 → 打开 Binsen"
  print    "  不开也能用，只是便笺没打开时，会多出一张空白便笺。打开后重跑本脚本即可。"
fi

step "5/5 自检：模拟 iPhone 发来一条"
TEST="$INBOX/安装自检-$(date +%H%M%S).txt"
print -r -- "Binsen 已接通 ✅  $(date '+%m-%d %H:%M')" > "$TEST"
for i in {1..15}; do
  [[ -e "$TEST" ]] || break
  sleep 1
done

if [[ ! -e "$TEST" ]]; then
  ok "便笺里多了一张「Binsen 已接通 ✅」，这张可以直接删掉。"
  sleep 2.5
  FRONT=$(lsappinfo info -only bundleid "$(lsappinfo front)" 2>/dev/null || true)
  if [[ "$FRONT" == *com.apple.Stickies* ]]; then
    print -P "%F{yellow}!%f 焦点停在了便笺上，没能还给终端。打开「辅助功能」后通常就能解决。日志：$LOG"
  else
    ok "焦点已还给终端"
  fi
  print "\n下一步：在 iPhone 上建快捷指令，步骤见 README.md。"
  exit 0
fi

print "\n收件箱 15 秒内没被处理，单独测一下新建便笺…"
if "$BIN" --test "Binsen 自检：新建便笺正常"; then
  fail "新建便笺没问题，但后台没处理收件箱，多半是 iCloud 文件夹的访问权限。最近日志：\n$(tail -5 "$LOG" 2>/dev/null)"
else
  fail "新建便笺失败。请到 系统设置 → 隐私与安全性 → 辅助功能，允许 Binsen，然后重跑本脚本。最近日志：\n$(tail -5 "$LOG" 2>/dev/null)"
fi
