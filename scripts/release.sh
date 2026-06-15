#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" OdinMac/Info.plist)
ARCHIVE="releases/OdinMac-v${VERSION}-macOS-arm64.zip"

./build.sh

mkdir -p releases
rm -f "$ARCHIVE"
ditto --norsrc -c -k --keepParent OdinMac.app "$ARCHIVE"

echo ""
echo "Release created: $SCRIPT_DIR/$ARCHIVE"
shasum -a 256 "$ARCHIVE"
