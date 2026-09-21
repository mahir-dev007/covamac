#!/bin/bash
set -e

echo "🚀 Building CovaMac (Release Mode) with Swift Package Manager..."
swift build -c release

APP_NAME="CovaMac"
TARGET_DIR="CovaMac.app"
CONTENTS_DIR="$TARGET_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Assembling $APP_NAME.app bundle..."
rm -rf "$TARGET_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary (Create Universal 2 binary if both arches exist)
if [ -f ".build/arm64-apple-macosx/release/$APP_NAME" ] && [ -f ".build/x86_64-apple-macosx/release/$APP_NAME" ]; then
    echo "⚡️ Merging arm64 and x86_64 slices into Universal 2 binary..."
    lipo -create -output "$MACOS_DIR/$APP_NAME" ".build/arm64-apple-macosx/release/$APP_NAME" ".build/x86_64-apple-macosx/release/$APP_NAME"
elif [ -f ".build/release/$APP_NAME" ]; then
    cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
else
    cp ".build/debug/$APP_NAME" "$MACOS_DIR/$APP_NAME"
fi
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy App Icon and Logo Resources
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    echo "🎨 AppIcon.icns bundled successfully."
fi
if [ -f "AppIcon_1024.png" ]; then
    cp "AppIcon_1024.png" "$RESOURCES_DIR/AppLogo.png"
fi

# Write Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CovaMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.covamac.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>CovaMac</string>
    <key>CFBundleDisplayName</key>
    <string>CovaMac Pro</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>100</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>NSMicrophoneUsageDescription</key>
    <string>CovaMac requires microphone access to measure live audio levels during hardware diagnostic tests.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 CovaMac. All rights reserved.</string>
</dict>
</plist>
EOF

# Write PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Refresh bundle metadata for Finder
if [ -f "AppIcon.icns" ]; then
    swift -e 'import AppKit; _ = NSWorkspace.shared.setIcon(NSImage(contentsOfFile: "AppIcon.icns")!, forFile: "CovaMac.app", options: [])' 2>/dev/null || true
fi
touch "$TARGET_DIR"

# Code sign with Hardened Runtime and entitlements
echo "🔏 Code-signing $APP_NAME.app bundle with Hardened Runtime..."
xattr -cr "$TARGET_DIR"
codesign --force --deep --options runtime --entitlements Entitlements.plist -s - "$TARGET_DIR"

echo "📦 Packaging CovaMac.zip for public distribution..."
rm -f CovaMac.zip
ditto -c -k --sequesterRsrc --keepParent "$TARGET_DIR" CovaMac.zip

echo "✅ Successfully built $TARGET_DIR with new custom logo!"
echo "🎁 Distribution package ready: CovaMac.zip"
echo "You can launch the app via: open ./$TARGET_DIR"

