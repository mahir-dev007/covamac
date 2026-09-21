#!/bin/bash
set -e

# ==============================================================================
# CovaMac — Production Release & Shipping Automation Script
# ==============================================================================
# Builds Universal 2 (arm64 + x86_64) release binaries, assembles the .app bundle
# with Hardened Runtime entitlements, packages a branded .dmg installer and .zip
# distribution archive, generates SHA-256 checksums, and handles Apple Notarization.
# ==============================================================================

VERSION="1.0.0"
BUILD_NUMBER="100"
APP_NAME="CovaMac"
DISPLAY_NAME="CovaMac Pro"
BUNDLE_ID="com.covamac.app"
DIST_DIR="dist"
TARGET_APP="$DIST_DIR/$APP_NAME.app"
DMG_NAME="CovaMac-$VERSION.dmg"
ZIP_NAME="CovaMac-$VERSION.zip"
DMG_PATH="$DIST_DIR/$DMG_NAME"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

SIGN_IDENTITY=""
NOTARIZE_PROFILE=""
SKIP_DMG=false

# Print Usage Help
print_help() {
    cat << EOF
Usage: ./package_release.sh [OPTIONS]

Options:
  --sign-id <IDENTITY>        Code signing identity (e.g. "Developer ID Application: Your Name (TEAM_ID)")
                              If omitted, auto-detects from keychain or defaults to Hardened Runtime ad-hoc.
  --notarize-profile <NAME>   Keychain profile for xcrun notarytool (submits DMG to Apple for notarization)
  --skip-dmg                  Skip disk image (.dmg) creation and only build .app and .zip
  -h, --help                  Show this help message

Examples:
  # Local test build (ad-hoc Hardened Runtime):
  ./package_release.sh

  # Production build with Apple Developer ID certificate:
  ./package_release.sh --sign-id "Developer ID Application: ACME Inc (ABCDE12345)"

  # Full automated build, sign, and Apple Notarization:
  ./package_release.sh --sign-id "Developer ID Application: ACME Inc (ABCDE12345)" --notarize-profile "ACME_NOTARY"

EOF
}

# Parse Command Line Arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sign-id)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --notarize-profile)
            NOTARIZE_PROFILE="$2"
            shift 2
            ;;
        --skip-dmg)
            SKIP_DMG=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

echo "=================================================================="
echo "🚀 Preparing $DISPLAY_NAME v$VERSION (Build $BUILD_NUMBER) for Shipping"
echo "=================================================================="

# 1. Check Code Signing Identity
if [ -z "$SIGN_IDENTITY" ]; then
    AUTO_DEV_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application:" | head -n 1 | awk -F '"' '{print $2}' || true)
    if [ -n "$AUTO_DEV_ID" ]; then
        SIGN_IDENTITY="$AUTO_DEV_ID"
        echo "🔑 Auto-detected Developer ID Certificate: $SIGN_IDENTITY"
    else
        SIGN_IDENTITY="-"
        echo "ℹ️  No Developer ID certificate detected. Signing with Hardened Runtime ad-hoc signature (-)."
        echo "   (To sign with an Apple Developer ID, pass --sign-id \"Developer ID Application: ...\")"
    fi
else
    echo "🔑 Using specified Developer ID Certificate: $SIGN_IDENTITY"
fi

# 2. Compile Universal 2 Release Slices (arm64 + x86_64)
echo ""
echo "⚙️  [1/6] Compiling Universal 2 Native Release Binaries..."

echo "   -> Building arm64 (Apple Silicon M1/M2/M3/M4)..."
swift build -c release --triple arm64-apple-macosx

echo "   -> Building x86_64 (Intel 64-bit)..."
swift build -c release --triple x86_64-apple-macosx

# 3. Assemble the .app Bundle
echo ""
echo "📦 [2/6] Assembling $APP_NAME.app bundle in ./$DIST_DIR/..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

CONTENTS_DIR="$TARGET_APP/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Merge slices with lipo
echo "   -> Merging slices into fat universal Mach-O binary..."
lipo -create -output "$MACOS_DIR/$APP_NAME" \
    ".build/arm64-apple-macosx/release/$APP_NAME" \
    ".build/x86_64-apple-macosx/release/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Icon & Asset Resources
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -f "AppIcon_1024.png" ]; then
    cp "AppIcon_1024.png" "$RESOURCES_DIR/AppLogo.png"
fi

# Write Production Info.plist
echo "   -> Writing production Info.plist..."
cat << EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
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

# Refresh bundle icon for Finder
if [ -f "AppIcon.icns" ]; then
    swift -e "import AppKit; _ = NSWorkspace.shared.setIcon(NSImage(contentsOfFile: \"AppIcon.icns\")!, forFile: \"$TARGET_APP\", options: [])" 2>/dev/null || true
fi
touch "$TARGET_APP"

# 4. Code Sign with Hardened Runtime & Entitlements
echo ""
echo "🔏 [3/6] Code-signing bundle with Hardened Runtime..."
xattr -cr "$TARGET_APP"

ENTITLEMENTS_FLAG=""
if [ -f "Entitlements.plist" ]; then
    ENTITLEMENTS_FLAG="--entitlements Entitlements.plist"
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --deep --options runtime $ENTITLEMENTS_FLAG -s - "$TARGET_APP"
else
    codesign --force --deep --options runtime --timestamp $ENTITLEMENTS_FLAG -s "$SIGN_IDENTITY" "$TARGET_APP"
fi

# Verify signature
codesign --verify --deep --strict --verbose=1 "$TARGET_APP"
echo "   -> Code signature verified successfully."

# 5. Create Distribution DMG & ZIP Archives
echo ""
echo "📀 [4/6] Creating release distribution packages..."

# A. ZIP Package
echo "   -> Creating $ZIP_NAME..."
ditto -c -k --sequesterRsrc --keepParent "$TARGET_APP" "$ZIP_PATH"

# B. Branded DMG Package
if [ "$SKIP_DMG" = false ]; then
    echo "   -> Assembling $DMG_NAME installer..."
    DMG_STAGING="$DIST_DIR/dmg_staging"
    rm -rf "$DMG_STAGING"
    mkdir -p "$DMG_STAGING"

    # Copy App and /Applications symlink
    ditto "$TARGET_APP" "$DMG_STAGING/$APP_NAME.app"
    ln -s /Applications "$DMG_STAGING/Applications"

    # Copy volume icon if present
    if [ -f "AppIcon.icns" ]; then
        cp "AppIcon.icns" "$DMG_STAGING/.VolumeIcon.icns"
        if command -v SetFile &>/dev/null; then
            SetFile -c icnC "$DMG_STAGING/.VolumeIcon.icns" 2>/dev/null || true
            SetFile -a C "$DMG_STAGING" 2>/dev/null || true
        fi
    fi

    # Create temporary writable DMG
    TMP_DMG="$DIST_DIR/temp.dmg"
    rm -f "$TMP_DMG" "$DMG_PATH"

    hdiutil create -srcfolder "$DMG_STAGING" \
        -volname "CovaMac Pro Installer" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        -size 150m \
        "$TMP_DMG" -quiet

    # Convert to compressed, read-only final DMG
    hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -quiet
    rm -f "$TMP_DMG"
    rm -rf "$DMG_STAGING"

    # Sign the DMG if Developer ID certificate is configured
    if [ "$SIGN_IDENTITY" != "-" ]; then
        echo "   -> Signing DMG installer..."
        codesign --force --timestamp -s "$SIGN_IDENTITY" "$DMG_PATH"
    fi
fi

# 6. Apple Notarization (if requested)
if [ -n "$NOTARIZE_PROFILE" ]; then
    echo ""
    echo "☁️  [5/6] Submitting package to Apple Notary Service..."
    if [ -f "$DMG_PATH" ]; then
        xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARIZE_PROFILE" --wait
        echo "   -> Stapling ticket to DMG installer..."
        xcrun stapler staple "$DMG_PATH"
    fi
    xcrun stapler staple "$TARGET_APP"
    echo "   -> Stapling ticket to $APP_NAME.app..."
else
    echo ""
    echo "ℹ️  [5/6] Apple Notarization skipped (pass --notarize-profile <name> to notarize)."
fi

# 7. Generate Cryptographic Checksums (SHA-256)
echo ""
echo "🔒 [6/6] Computing cryptographic SHA-256 checksums..."
CHECKSUMS_FILE="$DIST_DIR/SHA256SUMS.txt"
rm -f "$CHECKSUMS_FILE"

(
    cd "$DIST_DIR"
    if [ -f "$DMG_NAME" ] && [ -f "$ZIP_NAME" ]; then
        shasum -a 256 "$DMG_NAME" "$ZIP_NAME" > "SHA256SUMS.txt"
    elif [ -f "$ZIP_NAME" ]; then
        shasum -a 256 "$ZIP_NAME" > "SHA256SUMS.txt"
    fi
)

# Print Summary
echo ""
echo "=================================================================="
echo "🎉 SUCCESS: $DISPLAY_NAME is packaged and ready for shipping!"
echo "=================================================================="
echo "📍 Distribution files in ./$DIST_DIR/:"
ls -lh "$DIST_DIR"
echo ""
echo "📋 SHA-256 Hashes:"
cat "$CHECKSUMS_FILE"
echo "=================================================================="
echo "Ready to upload to GitHub Releases, your CDN, or Framer website!"
