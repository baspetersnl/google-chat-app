#!/usr/bin/env bash
# Google Chat voor macOS
# Copyright (C) 2026 Bas Peters
#
# This program is free software: you can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program. If not,
# see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Bouwt "build/Google Chat.app". Met "install" wordt de app daarna naar /Applications gekopieerd.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Google Chat.app"
ICON="$ROOT/build/AppIcon.icns"

cd "$ROOT"

swift build -c release --build-system native
BINARY="$(swift build -c release --build-system native --show-bin-path)/GoogleChat"

if [[ ! -f "$ICON" ]]; then
    ICONSET="$ROOT/build/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    swift "$ROOT/scripts/make-icon.swift" "$ROOT/build/AppIcon.png"

    for size in 16 32 128 256 512; do
        sips -z $size $size "$ROOT/build/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) "$ROOT/build/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done

    iconutil -c icns "$ICONSET" -o "$ICON"
    rm -rf "$ICONSET"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/GoogleChat"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc ondertekenen: nodig voor notificaties en camera/microfoon-toestemming.
codesign --force --sign - "$APP"

echo "Gebouwd: $APP"

if [[ "${1:-}" == "install" ]]; then
    rm -rf "/Applications/Google Chat.app"
    cp -R "$APP" "/Applications/Google Chat.app"
    echo "Geïnstalleerd: /Applications/Google Chat.app"
fi
