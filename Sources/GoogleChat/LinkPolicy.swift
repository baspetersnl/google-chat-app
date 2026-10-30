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

/// Decides which URLs stay in the app and which open in the default browser.
enum LinkPolicy {
    static let startURL = URL(string: "https://chat.google.com/")!

    /// Safari user agent, so Google does not block sign-in as an "embedded browser".
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    static func isInternal(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return true
        }

        if host == "chat.google.com" {
            return true
        }

        if host == "mail.google.com" {
            return url.path.hasPrefix("/chat")
        }

        // Landing page for signed-out users and the sign-in flow (including country domains such as google.nl).
        if host == "workspace.google.com" || host == "accounts.youtube.com" {
            return true
        }

        return host.hasPrefix("accounts.google.")
            || (host == "www.google.com" && url.path.hasPrefix("/accounts"))
            || (isGoogleDomain(host) && url.path.hasPrefix("/accounts/SetSID"))
    }

    /// google.com, google.nl, google.co.uk and their subdomains.
    private static func isGoogleDomain(_ host: String) -> Bool {
        host.split(separator: ".").contains("google")
    }

    static func isWeb(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
    }
}
