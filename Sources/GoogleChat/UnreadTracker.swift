// Google Chat for macOS
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

/// Collects the unread state from all frames and sets the badge on the Dock icon:
/// a number when one can be found, otherwise a dot when Chat shows that something is unread.
@MainActor
final class UnreadTracker: NSObject, WKScriptMessageHandler {
    static let messageName = "gchatUnread"

    private struct FrameState {
        let title: String
        let icons: [String]
        let labels: [String]
        let isMainFrame: Bool
        var lastSeen: SuspendingClock.Instant
    }

    /// Subframes can be removed without notice; the main frame keeps Chat's Home shortcut and is
    /// only dropped by `reset()`.
    private static let frameTimeout: Duration = .seconds(120)
    private static let maximumFrames = 50

    private var frames: [String: FrameState] = [:]
    private var hadUnread = false

    /// Called when the unread state changes from unread to nothing unread.
    var onAllRead: (() -> Void)?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let payload = message.body as? [String: Any], let frame = payload["frame"] as? String else {
            return
        }

        if (payload["gone"] as? Bool) == true {
            removeFrame(frame)
            updateBadge()
            return
        }

        let url = payload["url"] as? String ?? ""
        let state = FrameState(
            title: payload["title"] as? String ?? "",
            icons: payload["icons"] as? [String] ?? [],
            labels: payload["labels"] as? [String] ?? [],
            isMainFrame: message.frameInfo.isMainFrame,
            lastSeen: .now
        )

        if (payload["alive"] as? Bool) == true {
            // A heartbeat only refreshes a known frame. A frame that was pruned while its timers were
            // throttled is added back, because the shim only reports changes and would stay missing.
            if frames[frame] != nil {
                frames[frame]?.lastSeen = .now
                pruneFrames()
                updateBadge()
                return
            }
            NSLog("Unread frame restored: \(frame)")
        }

        frames[frame] = state

        if !state.icons.isEmpty || !state.labels.isEmpty {
            NSLog("Unread state \(url): title=\(state.title) icons=\(state.icons) labels=\(state.labels)")
        }

        pruneFrames()
        updateBadge()
    }

    /// Forgets frames of earlier pages after a full page load.
    func reset() {
        frames.removeAll()
        updateBadge()
    }

    private func removeFrame(_ frame: String) {
        if frames.removeValue(forKey: frame) != nil {
            NSLog("Unread frame removed: \(frame)")
        }
    }

    private func pruneFrames() {
        let deadline = SuspendingClock.now - Self.frameTimeout

        for frame in frames.filter({ !$0.value.isMainFrame && $0.value.lastSeen < deadline }).keys {
            removeFrame(frame)
        }

        while frames.count > Self.maximumFrames,
              let oldest = frames.filter({ !$0.value.isMainFrame }).min(by: { $0.value.lastSeen < $1.value.lastSeen })?.key {
            removeFrame(oldest)
        }
    }

    private func updateBadge() {
        let states = Array(frames.values)
        let titleCount = states.compactMap { UnreadCount.parse($0.title) }.max() ?? 0
        let labelCount = states.map { UnreadCount.count(labels: $0.labels) }.max() ?? 0
        let count = max(titleCount, labelCount)

        let badge: String?
        if count > 0 {
            badge = String(count)
        } else if states.contains(where: { UnreadCount.hasUnreadIcon($0.icons) }) {
            badge = "•"
        } else {
            badge = nil
        }

        if badge != NSApp.dockTile.badgeLabel {
            NSLog("Unread badge: \(NSApp.dockTile.badgeLabel ?? "none") -> \(badge ?? "none") (frames=\(states.count))")
            NSApp.dockTile.badgeLabel = badge
        }

        // An empty state right after a page load (no frames yet) does not count as read.
        guard !states.isEmpty else {
            return
        }

        let hasUnread = NSApp.dockTile.badgeLabel != nil
        if hadUnread, !hasUnread {
            onAllRead?()
        }
        hadUnread = hasUnread
    }
}
