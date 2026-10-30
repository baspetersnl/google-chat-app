// Google Chat voor macOS
// Copyright (C) 2026 Bas Peters
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
// even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with this program. If not,
// see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import WebKit

/// Verzamelt de ongelezen-status uit alle frames en zet de badge op het Dock-icoon.
/// Een getal als dat te vinden is, anders een stip als Chat wel laat zien dat er iets ongelezen is.
@MainActor
final class UnreadTracker: NSObject, WKScriptMessageHandler {
    static let messageName = "gchatUnread"

    private struct FrameState {
        let title: String
        let icons: [String]
        let labels: [String]
    }

    private var frames: [String: FrameState] = [:]

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let payload = message.body as? [String: Any], let frame = payload["frame"] as? String else {
            return
        }

        let url = payload["url"] as? String ?? ""
        let state = FrameState(
            title: payload["title"] as? String ?? "",
            icons: payload["icons"] as? [String] ?? [],
            labels: payload["labels"] as? [String] ?? []
        )
        frames[frame] = state

        if !state.icons.isEmpty || !state.labels.isEmpty {
            NSLog("Ongelezen-status \(url): titel=\(state.title) icons=\(state.icons) labels=\(state.labels)")
        }
        updateBadge()
    }

    /// Vergeet frames van eerdere pagina's na een volledige paginalading.
    func reset() {
        frames.removeAll()
        updateBadge()
    }

    private func updateBadge() {

        let states = Array(frames.values)
        let titleCount = states.compactMap { UnreadCount.parse($0.title) }.max() ?? 0
        let labelCount = states.map { UnreadCount.count(labels: $0.labels) }.max() ?? 0
        let count = max(titleCount, labelCount)

        if count > 0 {
            NSApp.dockTile.badgeLabel = String(count)
        } else if states.contains(where: { UnreadCount.hasUnreadIcon($0.icons) }) {
            NSApp.dockTile.badgeLabel = "•"
        } else {
            NSApp.dockTile.badgeLabel = nil
        }
    }
}
