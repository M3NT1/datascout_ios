#!/usr/bin/env bash
set -euo pipefail

# DataScout IPA csomagoló script
# Használat: ./scripts/package_ipa.sh

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"

echo "🔨 DataScout Release build fordítása..."
cd "$PROJECT_ROOT"
xcodebuild -scheme DataScout \
    -destination 'generic/platform=iOS' \
    -configuration Release \
    -allowProvisioningUpdates \
    build > /dev/null

APP_PATH=$(find "$DERIVED_DATA_DIR" -name "DataScout.app" -path "*/Release-iphoneos/*" | head -n1)

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "❌ Nem található a lefordított DataScout.app a Release-iphoneos mappában!"
    exit 1
fi

echo "📦 IPA csomag készítése ($APP_PATH)..."
rm -rf "$BUILD_DIR/Payload"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP_PATH" "$BUILD_DIR/Payload/"

cd "$BUILD_DIR"
zip -qr "DataScout.ipa" Payload
echo "✅ Elkészült: $BUILD_DIR/DataScout.ipa ($(du -h DataScout.ipa | cut -f1))"
