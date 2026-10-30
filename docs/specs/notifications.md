# Notifications

Status: implemented in 1.0.0, verified working on 2026-10-30.

## Behaviour

- Every notification Google Chat creates is shown in the macOS Notification Center, with the sender's
  avatar as attachment and the default sound (unless the page asks for a silent notification).
- Notifications with the same `tag` replace each other.
- Notifications are grouped per conversation (one stack per direct message or space) when the user's
  "Group notifications" setting for the app is "Automatic".
- Notifications are also shown while the app is in the foreground (Chat itself decides whether to notify).
- Clicking a notification brings the app to the front, shows the window if it was hidden, and opens the
  conversation the notification belongs to.

## Acceptance criteria

- With the window hidden (Cmd+W), an incoming message produces a macOS notification.
- Clicking it shows the window with that conversation open, both for direct messages and for spaces.
- Chat's own "enable notifications" prompt does not appear: the page sees permission `granted`.

## Implementation

`NotificationShim` (JavaScript, all frames, document start) replaces:

- `window.Notification` with `NativeNotification` (`permission` is always `granted`,
  `requestPermission()` resolves `granted`);
- `navigator.permissions.query({ name: 'notifications' })` to report `granted`;
- `ServiceWorkerRegistration.prototype.showNotification` / `getNotifications`.

Each notification is posted to the `gchatNotification` handler with `id`, `title`, `body`, `tag`,
`icon` (absolute URL), `silent`, `source` (`page` or `serviceWorker`), `thread` (`<kind>/<id>` of the
conversation, empty when not found) and `data` (JSON, max 2000 chars, for logging). `NotificationBridge` shows it with `UNUserNotificationCenter`:

- request identifier `tag:<tag>` when a tag exists, otherwise the shim's id;
- `threadIdentifier` is `thread`, falling back to the tag. The tag alone does not group anything, because
  Chat makes it unique per message (see below);
- the avatar is downloaded (3 s timeout) and converted to PNG, because Notification Center does not
  accept WebP;
- the frame that created the notification is remembered (last 200) for the click.

### Click handling

1. `NotificationBridge` evaluates `window.__gchatNotificationClicked(id)` in the originating frame (falls
   back to the main frame). The shim fires the notification's `click` event and returns
   `{ found, source, hasHandler, kind, group, target }`.
2. If the page has no click handler, or the notification came from the service worker path, the app
   opens the conversation itself: first `window.__gchatOpenGroup(kind, id)`, which clicks the sidebar
   element `[data-group-id="<kind>/<id>"]`; if that element is not found, it loads `target`
   (`<origin><prefix>/app/chat/<id>`).

## Observed Chat behaviour (2026-10-30)

- Chat uses the **service worker path** (`source = serviceWorker`), so nobody listens to the click event.
- `notification.data` is a **JSON string**, not an object, and contains no URL. Structure for a direct message (real ids replaced by placeholders):
  ```json
  ["<messageId>/<userId>",[[null,null,null,[null,"<messageId>",[null,null,["<dmId>"]]]],"<messageId>"]]
  ```
  The conversation is identified by a GroupId: `[null, null, ["<dmId>"]]` for a direct message,
  `[["<spaceId>"]]` for a space (space shape inferred from the protobuf layout, not yet observed).
- The `tag` has the form `<messageId>/<userId>`, so it is unique per message and useless for grouping.
- Grouping per conversation relies on the same GroupId. For spaces the shape is still unverified; if it
  differs, space notifications log `thread=` (empty) and are not grouped.
- Which of the two click paths (sidebar or URL) actually opened the conversation was not logged. If
  clicks stop working, check the `Opening conversation ... through the sidebar` log line first.

## Known limitations

- Notification actions (reply from the notification) are not supported (`maxActions` is 0).
- If Chat changes the data format, clicks only bring the app to the front. The `Notification` log line
  contains the raw data for diagnosis.
