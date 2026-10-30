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
import UserNotifications
import WebKit

/// Ontvangt notificaties uit de shim, toont ze via het macOS Notification Center
/// en stuurt een klik terug naar de frame die de notificatie maakte.
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
                NSLog("Toestemming voor notificaties mislukt: \(error.localizedDescription)")
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
            NSLog("Notificatie \(id): bron=\(payload["source"] ?? "") tag=\(tag) data=\(payload["data"] ?? "")")
            remember(frame: message.frameInfo, for: id)
            show(id: id, tag: tag, payload: payload)
        case "close":
            center.removeDeliveredNotifications(withIdentifiers: [identifier(id: id, tag: tag)])
        default:
            break
        }
    }

    /// Een tag vervangt een eerdere notificatie met dezelfde tag, net als in de browser.
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
                NSLog("Notificatie tonen mislukt: \(error.localizedDescription)")
            }
        }
    }

    /// Haalt de avatar op en zet hem om naar PNG; Notification Center accepteert geen WebP.
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
                NSLog("Notificatieklik \(jsId) mislukt in frame: \(error.localizedDescription)")
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

    /// Doet de pagina zelf niets met de klik (bij service-worker-notificaties luistert er niemand),
    /// dan opent de app het gesprek: eerst via de zijbalk, anders door het adres te laden.
    private func handleClickResult(_ value: Any, jsId: String) {
        let result = value as? [String: Any] ?? [:]
        NSLog("Notificatieklik \(jsId): \(result)")

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
            NSLog("Gesprek \(kind)/\(group) openen via zijbalk: \(opened ? "gelukt" : "niet gevonden")")

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
