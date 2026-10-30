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

import Foundation

/// Extracts the number of unread messages from Chat's titles, aria-labels and favicons.
enum UnreadCount {
    private static let titlePatterns = [
        #"\((\d+)\)"#,
        #"(\d+)\s+(?:unread|ongelezen)"#,
    ]

    private static let labelNumberPattern = #"(\d+)\s+(?:unread|ongelezen)"#
    private static let homePattern = #"home\b.*?(\d+)\s+(?:unread|ongelezen)"#

    /// For example "Chat (3)" or "3 unread".
    static func parse(_ title: String) -> Int? {
        for pattern in titlePatterns {
            if let count = firstNumber(in: title, pattern: pattern), count > 0 {
                return count
            }
        }

        return nil
    }

    /// Chat puts the total on the Home shortcut ("Home shortcut, 3 unread messages").
    /// Without that shortcut, the highest number from a label such as "2 unread messages" is used.
    /// Labels without a number ("Mark as unread") are buttons and are ignored.
    static func count(labels: [String]) -> Int {
        if let home = labels.lazy.compactMap({ firstNumber(in: $0, pattern: homePattern) }).first {
            return home
        }

        return labels.compactMap { firstNumber(in: $0, pattern: labelNumberPattern) }.max() ?? 0
    }

    /// With unread messages, Chat switches from "..._favicon_no_dot_..." to a favicon with a dot.
    static func hasUnreadIcon(_ icons: [String]) -> Bool {
        icons.contains {
            $0.range(of: #"(?<!no_)dot|notif|unread|badge"#, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func firstNumber(in text: String, pattern: String) -> Int? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else {
            return nil
        }

        for group in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: group), in: text), let number = Int(text[range]) {
                return number
            }
        }

        return nil
    }
}
