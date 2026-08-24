#!/bin/bash
# 将 FRB Rust 动态库打包进 macOS App（Contents/Frameworks），并带 entitlements 重签名。
# 用法：client/scripts/bundle_rust_macos.sh [build_config]
#   build_config: Debug（默认）| Release | Profile
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-Debug}"

if [ "$CONFIG" = "Debug" ]; then
  CARGO_FLAGS=""
  ENTITLEMENTS="macos/Runner/DebugProfile.entitlements"
elif [ "$CONFIG" = "Profile" ]; then
  CARGO_FLAGS="--release"
  ENTITLEMENTS="macos/Runner/Release.entitlements"
else
  CARGO_FLAGS="--release"
  ENTITLEMENTS="macos/Runner/Release.entitlements"
fi

# 1) 构建 Rust cdylib
(cd rust && cargo build $CARGO_FLAGS)

DYLIB="rust/target/debug/liblonisle_client_core.dylib"
[ "$CONFIG" != "Debug" ] && DYLIB="rust/target/release/liblonisle_client_core.dylib"
if [ ! -f "$DYLIB" ]; then
  echo "错误：未找到 $DYLIB" >&2
  exit 1
fi

APP="build/macos/Build/Products/$CONFIG/lonisle_client.app"
FW_DIR="$APP/Contents/Frameworks/lonisle_client_core.framework"
if [ ! -d "$APP" ]; then
  echo "错误：未找到 $APP（先 flutter build macos --debug）" >&2
  exit 1
fi

# 2) 组装 framework（macOS 规范深层布局 + 根符号链接供 @rpath 解析）
rm -rf "$FW_DIR"
mkdir -p "$FW_DIR/Versions/A/Resources"
cp "$DYLIB" "$FW_DIR/Versions/A/lonisle_client_core"
install_name_tool -id "@rpath/lonisle_client_core.framework/lonisle_client_core" \
  "$FW_DIR/Versions/A/lonisle_client_core"
ln -s A "$FW_DIR/Versions/Current"
ln -s "Versions/A/lonisle_client_core" "$FW_DIR/lonisle_client_core"
ln -s "Versions/A/Resources" "$FW_DIR/Resources"

cat > "$FW_DIR/Versions/A/Resources/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>lonisle_client_core</string>
	<key>CFBundleIdentifier</key>
	<string>com.lonisle.client.core</string>
	<key>CFBundleName</key>
	<string>lonisle_client_core</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
</dict>
</plist>
EOF

# 3) 签名（先 framework，再 App 带 entitlements —— 保持 Keychain/网络等权限不变）
codesign --force --sign - --timestamp=none "$FW_DIR/Versions/A/lonisle_client_core"
codesign --force --sign - --timestamp=none \
  --entitlements "$ENTITLEMENTS" "$APP"

echo "✓ 已打包 Rust 库并以 $ENTITLEMENTS 重签名"
