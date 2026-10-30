# 0002. Emulate the Web Notification API with a shim

Date: 2026-10-30. Status: accepted.

## Context

`WKWebView` does not expose the Web Notification API, and there is no public API to grant it. Without it,
Google Chat never creates notifications.

## Decision

Inject `NotificationShim` at document start into all frames. It replaces `window.Notification`,
`navigator.permissions.query` for notifications and `ServiceWorkerRegistration.showNotification`, reports
permission `granted`, and forwards every notification to Swift, which shows it with
`UNUserNotificationCenter`. Clicks are sent back to the page; when the page does not handle them (the
service worker path), the app parses the conversation id from `notification.data` and opens it.

## Consequences

- Notifications work without Chrome or a browser extension.
- Opening the right conversation depends on Chat's internal `notification.data` format and the
  `data-group-id` attribute in the sidebar (see [notifications spec](../specs/notifications.md)).
- Notification actions (inline reply) are not supported.
