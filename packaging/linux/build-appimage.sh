#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build-linux}"
APPDIR="${APPDIR:-$ROOT/dist/AppDir}"
JOBS="${JOBS:-$(nproc)}"

cmake -S "$ROOT" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$BUILD" --parallel "$JOBS"
rm -rf "$APPDIR"
DESTDIR="$APPDIR" cmake --install "$BUILD"

install -Dm644 "$ROOT/packaging/linux/library.png" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/com.bubaimengj4.LibraryManagementSystem.png"
install -Dm644 "$ROOT/packaging/linux/com.bubaimengj4.LibraryManagementSystem.desktop" \
  "$APPDIR/usr/share/applications/com.bubaimengj4.LibraryManagementSystem.desktop"
install -Dm644 "$ROOT/packaging/linux/com.bubaimengj4.LibraryManagementSystem.metainfo.xml" \
  "$APPDIR/usr/share/metainfo/com.bubaimengj4.LibraryManagementSystem.metainfo.xml"

if ! command -v linuxdeploy >/dev/null 2>&1; then
  curl -L -o /tmp/linuxdeploy.AppImage \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
  chmod +x /tmp/linuxdeploy.AppImage
  LINUXDEPLOY=/tmp/linuxdeploy.AppImage
else
  LINUXDEPLOY="$(command -v linuxdeploy)"
fi

if ! command -v linuxdeploy-plugin-qt >/dev/null 2>&1; then
  curl -L -o /tmp/linuxdeploy-plugin-qt.AppImage \
    https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
  chmod +x /tmp/linuxdeploy-plugin-qt.AppImage
  export LINUXDEPLOY_PLUGIN_QT=/tmp/linuxdeploy-plugin-qt.AppImage
fi

export QMAKE="${QMAKE:-$(command -v qmake6 || command -v qmake)}"
"$LINUXDEPLOY" --appdir "$APPDIR" --plugin qt --output appimage
