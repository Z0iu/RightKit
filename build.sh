#!/usr/bin/env bash
# 一键构建 + 签名 + 安装 + 注册扩展
set -euo pipefail
cd "$(dirname "$0")"

SDK=$(xcrun --show-sdk-path)
APP=build/RightKit.app
EXT=$APP/Contents/PlugIns/RightKitExt.appex

command -v swiftc >/dev/null || { echo "需要 Xcode 命令行工具：xcode-select --install"; exit 1; }

echo "==> 准备目录"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$EXT/Contents/MacOS"

echo "==> 编译宿主 App"
swiftc -O -target arm64-apple-macos13.0 -sdk "$SDK" -framework Cocoa \
  -o "$APP/Contents/MacOS/RightKit" src/main.swift

echo "==> 编译 FinderSync 扩展"
swiftc -O -parse-as-library -target arm64-apple-macos13.0 -sdk "$SDK" \
  -framework Cocoa -framework FinderSync \
  -o "$EXT/Contents/MacOS/RightKitExt" src/RightKitExt.swift \
  -Xlinker -e -Xlinker _NSExtensionMain

echo "==> 写入 Info.plist / 资源"
cp src/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist.app "$APP/Contents/Info.plist"
cp Info.plist.ext "$EXT/Contents/Info.plist"

echo "==> ad-hoc 签名"
codesign --force --sign - --timestamp=none --entitlements src/ext.entitlements "$EXT"
codesign --force --sign - --timestamp=none "$APP"

echo "==> 安装到 ~/Applications"
mkdir -p ~/Applications
rm -rf ~/Applications/RightKit.app
cp -R "$APP" ~/Applications/

LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
$LSR -f ~/Applications/RightKit.app || true
pluginkit -a ~/Applications/RightKit.app/Contents/PlugIns/RightKitExt.appex || true
pluginkit -e use -i com.ln.rightkit.ext || true

echo "==> 完成。右键桌面试试。"
echo "    状态：pluginkit -m -p com.apple.FinderSync | grep rightkit"
