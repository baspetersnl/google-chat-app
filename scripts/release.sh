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

# Maakt een release van de versie in Support/Info.plist: bouwt de app, pakt hem in als zip,
# zet de tag v<versie> en pusht die. Met de GitHub CLI (gh) wordt de release ook gepubliceerd.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)"
TAG="v$VERSION"
ZIP="$ROOT/build/Google-Chat-$VERSION.zip"
NOTES="$ROOT/build/release-notes-$VERSION.md"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Er staan nog niet-gecommitte wijzigingen. Commit die eerst." >&2
    exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG bestaat al. Verhoog CFBundleShortVersionString in Support/Info.plist." >&2
    exit 1
fi

"$ROOT/scripts/build.sh"

rm -f "$ZIP"
ditto -c -k --keepParent "$ROOT/build/Google Chat.app" "$ZIP"
echo "Ingepakt: $ZIP"

cat > "$NOTES" <<EOF
## Installation

1. Download \`Google-Chat-$VERSION.zip\` and unzip it.
2. Drag **Google Chat.app** to your Applications folder.
3. The app is not notarized by Apple. If macOS says the app cannot be opened, go to
   System Settings > Privacy & Security and click **Open Anyway**. Or run this in Terminal:

   \`\`\`sh
   xattr -dr com.apple.quarantine "/Applications/Google Chat.app"
   \`\`\`

Requires macOS 14 or later.
EOF

git tag -a "$TAG" -m "Versie $VERSION"
git push origin "$TAG"
echo "Tag gepusht: $TAG"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh release create "$TAG" "$ZIP" --title "Google Chat $VERSION" --notes-file "$NOTES"
else
    echo
    echo "GitHub CLI niet beschikbaar. Publiceer de release zelf:"
    echo "  https://github.com/baspetersnl/google-chat-app/releases/new?tag=$TAG"
    echo "  Bijlage:        $ZIP"
    echo "  Beschrijving:   $NOTES"
fi
