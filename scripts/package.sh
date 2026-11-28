#!/bin/zsh
# Binsen · 打包发布用的安装包（Apple 芯片和 Intel 通用），输出到 dist/：
#   Binsen.zip          macOS 26 及以后（全出血图标，由系统裁成圆角）
#   Binsen-legacy.zip   macOS 13–15（自带圆角和阴影的图标）
#   SHA256SUMS.txt
# 用法：zsh scripts/package.sh            GitHub Actions 发布 Release 时也调用它
# 签名：设置了 SIGN_IDENTITY 就用它签名（Developer ID 会同时开启 Hardened Runtime，供公证）；没设置就用临时签名。
# 公证：NOTARY_APPLE_ID、NOTARY_TEAM_ID、NOTARY_PASSWORD（App 专用密码）都设置了才公证并装订。
set -eu
setopt pipefail

ROOT=${0:A:h:h}
NAME=Binsen
ID=io.github.qinov5.binsen
DIST="$ROOT/dist"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/binsen-package.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Info.plist")
CODE_VERSION=$(sed -n 's/^let appVersion = "\(.*\)"$/\1/p' "$ROOT/Sources/main.swift")
if [[ "$VERSION" != "$CODE_VERSION" ]]; then
  print "版本号不一致：Info.plist 是 $VERSION，main.swift 是 $CODE_VERSION"
  exit 1
fi
if [[ -n "${RELEASE_TAG:-}" && "${RELEASE_TAG#v}" != "$VERSION" ]]; then
  print "发布标签 $RELEASE_TAG 和版本号 $VERSION 不一致"
  exit 1
fi

print "编译 Binsen $VERSION（arm64 + x86_64，最低 macOS 13）"
for arch in arm64 x86_64; do
  xcrun swiftc -O -swift-version 5 -target "$arch-apple-macos13.0" \
    -o "$WORK/$NAME-$arch" "$ROOT/Sources/main.swift"
done
lipo -create -output "$WORK/$NAME-universal" "$WORK/$NAME-arm64" "$WORK/$NAME-x86_64"

SIGN=${SIGN_IDENTITY:--}
NOTARIZE=0
[[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_TEAM_ID:-}" && -n "${NOTARY_PASSWORD:-}" ]] && NOTARIZE=1
mkdir -p "$DIST"

# pack 图标文件 输出文件名
pack() {
  local icon=$1 zip="$DIST/$2" app="$WORK/${2%.zip}-app/$NAME.app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$WORK/$NAME-universal" "$app/Contents/MacOS/$NAME"
  cp "$ROOT/Info.plist" "$app/Contents/Info.plist"
  cp "$ROOT/Icon/$icon" "$app/Contents/Resources/AppIcon.icns"
  if [[ "$SIGN" == "Developer ID Application"* ]]; then
    codesign --force --options runtime --timestamp --entitlements "$ROOT/Binsen.entitlements" \
      --sign "$SIGN" --identifier "$ID" "$app"
  else
    codesign --force --sign "$SIGN" --identifier "$ID" "$app"
  fi
  codesign --verify --deep --strict "$app"
  rm -f "$zip"
  ditto -c -k --keepParent "$app" "$zip"
  if (( NOTARIZE )); then
    xcrun notarytool submit "$zip" --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" \
      --password "$NOTARY_PASSWORD" --wait
    xcrun stapler staple "$app"
    rm -f "$zip"
    ditto -c -k --keepParent "$app" "$zip"
  fi
  print "✓ dist/$2"
}

pack AppIcon.icns Binsen.zip
pack AppIcon-legacy.icns Binsen-legacy.zip
(cd "$DIST" && shasum -a 256 Binsen.zip Binsen-legacy.zip > SHA256SUMS.txt)

if [[ "$SIGN" == "-" ]]; then
  SIGNED="临时签名"
else
  SIGNED="$SIGN"
fi
(( NOTARIZE )) && SIGNED="$SIGNED，已公证"
print "完成：Binsen $VERSION（$SIGNED）"
