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

/// Onzichtbare webview voor `window.open()` zonder URL. Zodra de pagina een echt adres laadt,
/// gaat dat adres naar `open` en ruimt de catcher zichzelf op.
@MainActor
final class PopupCatcher: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private let open: (URL) -> Void
    private let onFinish: (PopupCatcher) -> Void

    init(
        configuration: WKWebViewConfiguration,
        open: @escaping (URL) -> Void,
        onFinish: @escaping (PopupCatcher) -> Void
    ) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        self.open = open
        self.onFinish = onFinish
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, LinkPolicy.isWeb(url) else {
            decisionHandler(.allow)
            return
        }

        open(url)
        decisionHandler(.cancel)
        onFinish(self)
    }

    func webViewDidClose(_ webView: WKWebView) {
        onFinish(self)
    }
}
