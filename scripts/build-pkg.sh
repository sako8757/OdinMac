#!/bin/bash
# Builds OdinMac.app and wraps it into a signed-payload .pkg installer that
# installs to /Applications, clears quarantine, and auto-launches the app.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" OdinMac/Info.plist)
PKG_ID="com.odinmac.app.pkg"
BUILD_DIR=".build/pkg"
PKGROOT="$BUILD_DIR/root"
SCRIPTS_DIR="scripts/pkg-scripts"
RESOURCES_DIR="scripts/pkg-resources"
COMPONENT_PKG="$BUILD_DIR/OdinMac.pkg"
COMPONENT_PLIST="$BUILD_DIR/component.plist"
DISTRIBUTION_XML="$BUILD_DIR/distribution.xml"
OUTPUT_PKG="releases/OdinMac-v${VERSION}-macOS-arm64.pkg"

echo "==> Building OdinMac.app..."
./build.sh

echo "==> Assembling package root..."
rm -rf "$BUILD_DIR"
mkdir -p "$PKGROOT/Applications"
ditto OdinMac.app "$PKGROOT/Applications/OdinMac.app"

echo "==> Analyzing component package..."
pkgbuild --analyze --root "$PKGROOT" "$COMPONENT_PLIST"
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST"

echo "==> Building component package..."
pkgbuild \
  --root "$PKGROOT" \
  --component-plist "$COMPONENT_PLIST" \
  --scripts "$SCRIPTS_DIR" \
  --identifier "$PKG_ID" \
  --version "$VERSION" \
  --install-location "/" \
  "$COMPONENT_PKG"

echo "==> Generating distribution.xml..."
sed "s|\$(VERSION)|$VERSION|g" "$RESOURCES_DIR/distribution.xml" > "$DISTRIBUTION_XML"

echo "==> Building product package..."
mkdir -p releases
rm -f "$OUTPUT_PKG"
productbuild \
  --distribution "$DISTRIBUTION_XML" \
  --package-path "$BUILD_DIR" \
  --resources "$RESOURCES_DIR" \
  "$OUTPUT_PKG"

echo ""
echo "✓ Package created: $SCRIPT_DIR/$OUTPUT_PKG"
shasum -a 256 "$OUTPUT_PKG"
