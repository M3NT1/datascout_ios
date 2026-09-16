#!/usr/bin/env bash
set -euo pipefail

# DataScout Verziókezelő Script (Semantic Versioning)
# Használat:
#   ./scripts/bump_version.sh patch          -> 1.0.x (kisebb hibajavítások)
#   ./scripts/bump_version.sh minor          -> 1.x.0 (új funkció, nagyobb módosítás)
#   ./scripts/bump_version.sh major --confirm -> x.0.0 (architekturális váltás - külön engedéllyel!)

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_YML="$PROJECT_ROOT/project.yml"
APP_INFO_PLIST="$PROJECT_ROOT/DataScout/Resources/Info.plist"
WIDGET_INFO_PLIST="$PROJECT_ROOT/DataScoutWidgets/Info.plist"

TYPE="${1:-}"

if [[ -z "$TYPE" || ( "$TYPE" != "patch" && "$TYPE" != "minor" && "$TYPE" != "major" && "$TYPE" != "current" ) ]]; then
    echo "❌ Használat: $0 [patch | minor | major | current] [--confirm]"
    echo "   - patch:  Kisebb hibajavítás (1.0.x)"
    echo "   - minor:  Nagyobb javítás vagy új funkció (1.x.0)"
    echo "   - major:  Főverzió, architekturális változás (x.0.0) -> Külön engedély szükséges (--confirm)!"
    echo "   - current: Kiírja az aktuális verziót"
    exit 1
fi

# Aktuális verzió és build kiolvasása a project.yml-ből
CURRENT_VERSION=$(grep 'MARKETING_VERSION:' "$PROJECT_YML" | head -n1 | sed -E 's/.*MARKETING_VERSION: "([^"]+)".*/\1/')
CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -n1 | sed -E 's/.*CURRENT_PROJECT_VERSION: "([^"]+)".*/\1/')

if [[ "$TYPE" == "current" ]]; then
    echo "ℹ️  DataScout aktuális verzió: v$CURRENT_VERSION (Build $CURRENT_BUILD)"
    exit 0
fi

# Daraboljuk a verziószámot
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
MAJOR="${MAJOR:-1}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"
NEW_BUILD=$((CURRENT_BUILD + 1))

case "$TYPE" in
    patch)
        PATCH=$((PATCH + 1))
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    major)
        CONFIRM="${2:-}"
        if [[ "$CONFIRM" != "--confirm" ]]; then
            echo "⚠️  FIGYELEM: Főverzió (Major x.0.0) léptetése architekturális mérföldkő és külön engedélyköteles!"
            echo "   Megerősítéshez futtasd: $0 major --confirm"
            exit 2
        fi
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
echo "🚀 Verzióléptetés: v$CURRENT_VERSION (Build $CURRENT_BUILD) -> v$NEW_VERSION (Build $NEW_BUILD) [$TYPE]"

# project.yml frissítése
sed -i '' -E "s/MARKETING_VERSION: \"[^\"]+\"/MARKETING_VERSION: \"$NEW_VERSION\"/" "$PROJECT_YML"
sed -i '' -E "s/CURRENT_PROJECT_VERSION: \"[^\"]+\"/CURRENT_PROJECT_VERSION: \"$NEW_BUILD\"/" "$PROJECT_YML"

# Info.plist fájlok frissítése
if [[ -f "$APP_INFO_PLIST" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$APP_INFO_PLIST" || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$APP_INFO_PLIST" || true
fi

if [[ -f "$WIDGET_INFO_PLIST" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$WIDGET_INFO_PLIST" || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$WIDGET_INFO_PLIST" || true
fi

# XcodeGen újragenerálás
cd "$PROJECT_ROOT"
xcodegen generate >/dev/null

echo "✅ Sikeresen beállítva: v$NEW_VERSION (Build $NEW_BUILD)"
