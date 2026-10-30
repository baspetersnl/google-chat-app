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
import UserNotifications
import WebKit

/// Receives notifications from the shim, shows them in the macOS Notification Center
/// and sends a click back to the frame that created the notification.
@MainActor
final class NotificationBridge: NSObject, WKScriptMessageHandler {
    static let messageName = "gchatNotification"

    weak var webView: WKWebView?
    var onActivate: (() -> Void)?

    private let center = UNUserNotificationCenter.current()
    private var frames: [String: WKFrameInfo] = [:]
    private var frameOrder: [String] = []

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error {
                NSLog("Notification authorization failed: \(error.localizedDescription)")
            }
        }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            let payload = message.body as? [String: Any],
            let type = payload["type"] as? String,
            let id = payload["id"] as? String
        else {
            return
        }

        let tag = payload["tag"] as? String ?? ""

        switch type {
        case "show":
            NSLog("Notification \(id): source=\(payload["source"] ?? "") tag=\(tag) data=\(payload["data"] ?? "")")
            remember(frame: message.frameInfo, for: id)
            show(id: id, tag: tag, payload: payload)
        case "close":
            center.removeDeliveredNotifications(withIdentifiers: [identifier(id: id, tag: tag)])
        default:
            break
        }
    }

    /// A tag replaces an earlier notification with the same tag, as in the browser.
    private func identifier(id: String, tag: String) -> String {
        tag.isEmpty ? id : "tag:\(tag)"
    }

    private func remember(frame: WKFrameInfo, for id: String) {
        frames[id] = frame
        frameOrder.append(id)

        if frameOrder.count > 200 {
            frames.removeValue(forKey: frameOrder.removeFirst())
        }
    }

    private func show(id: String, tag: String, payload: [String: Any]) {
        let content = UNMutableNotificationContent()
        content.title = payload["title"] as? String ?? "Google Chat"
        content.body = payload["body"] as? String ?? ""
        content.userInfo = ["jsId": id]

        if !tag.isEmpty {
            content.threadIdentifier = tag
        }

        if (payload["silent"] as? Bool) != true {
            content.sound = .default
        }

        let iconURL = (payload["icon"] as? String).flatMap(URL.init(string:))
        let requestIdentifier = identifier(id: id, tag: tag)

        Task {
            if let iconURL, let attachment = await Self.attachment(for: iconURL) {
                content.attachments = [attachment]
            }

            let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: nil)

            do {
                try await center.add(request)
            } catch {
                NSLog("Showing notification failed: \(error.localizedDescription)")
            }
        }
    }

    /// Downloads the avatar and converts it to PNG, because Notification Center does not accept WebP.
    private static func attachment(for url: URL) async -> UNNotificationAttachment? {
        guard LinkPolicy.isWeb(url) else {
            return nil
        }

        var request = URLRequest(url: url, timeoutInterval: 3)
        request.setValue(LinkPolicy.userAgent, forHTTPHeaderField: "User-Agent")

        guard
            let (data, _) = try? await URLSession.shared.data(for: request),
            let image = NSImage(data: data),
            let tiff = image.tiffRepresentation,
            let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else {
            return nil
        }

        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        do {
            try png.write(to: file)
            return try UNNotificationAttachment(identifier: "icon", url: file)
        } catch {
            return nil
        }
    }

    private func handleClick(jsId: String?) {
        onActivate?()

        guard let jsId, let webView else {
            return
        }

        guard
            let data = try? JSONSerialization.data(withJSONObject: [jsId]),
            let argument = String(data: data, encoding: .utf8)
        else {
            return
        }

        let script = "window.__gchatNotificationClicked && window.__gchatNotificationClicked(...\(argument))"
        let frame = frames[jsId]

        webView.evaluateJavaScript(script, in: frame, in: .page) { [weak self] result in
            switch result {
            case .success(let value):
                self?.handleClickResult(value, jsId: jsId)
            case .failure(let error):
                NSLog("Notification click \(jsId) failed in frame: \(error.localizedDescription)")
                if frame != nil {
                    webView.evaluateJavaScript(script, in: nil, in: .page) { [weak self] result in
                        if case .success(let value) = result {
                            self?.handleClickResult(value, jsId: jsId)
                        }
                    }
                }
            }
        }
    }

    /// When the page does nothing with the click (nobody listens to service worker notifications),
    /// the app opens the conversation itself: through the sidebar first, otherwise by loading its URL.
    private func handleClickResult(_ value: Any, jsId: String) {
        let result = value as? [String: Any] ?? [:]
        NSLog("Notification click \(jsId): \(result)")

        let hasHandler = result["hasHandler"] as? Bool ?? false
        let fromServiceWorker = result["source"] as? String == "serviceWorker"

        guard
            !hasHandler || fromServiceWorker,
            let webView,
            let kind = result["kind"] as? String, !kind.isEmpty,
            let group = result["group"] as? String, !group.isEmpty,
            let arguments = try? JSONSerialization.data(withJSONObject: [kind, group]),
            let argumentList = String(data: arguments, encoding: .utf8)
        else {
            return
        }

        let target = (result["target"] as? String).flatMap(URL.init(string:))
        let script = "window.__gchatOpenGroup ? window.__gchatOpenGroup(...\(argumentList)) : 'missing'"

        webView.evaluateJavaScript(script, in: nil, in: .page) { [weak webView] outcome in
            let opened = (try? outcome.get()) as? String == "clicked"
            NSLog("Opening conversation \(kind)/\(group) through the sidebar: \(opened ? "succeeded" : "not found")")

            if !opened, let target, LinkPolicy.isInternal(target) {
                webView?.load(URLRequest(url: target))
            }
        }
    }
}

extension NotificationBridge: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let jsId = response.notification.request.content.userInfo["jsId"] as? String

        await MainActor.run {
            handleClick(jsId: jsId)
        }
    }
}
