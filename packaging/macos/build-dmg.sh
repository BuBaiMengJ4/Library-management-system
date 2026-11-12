#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build-macos}"
APP="$BUILD/bin/LibraryManagementSystem.app"
DIST="$ROOT/dist"
DMG="$DIST/LibraryManagementSystem-1.0.0-macos.dmg"

cmake -S "$ROOT" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH:-$QT_ROOT_DIR}"
cmake --build "$BUILD" --parallel "$(sysctl -n hw.ncpu)"

if command -v macdeployqt >/dev/null 2>&1; then
  macdeployqt "$APP" -qmldir="$ROOT/src/qml" -always-overwrite
fi

mkdir -p "$APP/Contents/qml"
if [ -d "$BUILD/qml/FluentUI" ]; then
  rm -rf "$APP/Contents/qml/FluentUI"
  cp -R "$BUILD/qml/FluentUI" "$APP/Contents/qml/FluentUI"
fi

mkdir -p "$DIST"
rm -f "$DMG"
hdiutil create -volname "Library Management System" \
  -srcfolder "$APP" -ov -format UDZO "$DMG"
echo "Created $DMG"
