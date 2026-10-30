# Background activity and window behaviour

Status: implemented in 1.0.0, verified working on 2026-10-30.

## Behaviour

- Closing the window (Cmd+W or the close button) only hides it. The app keeps running and keeps
  receiving messages and notifications. Cmd+Q quits.
- Clicking the Dock icon, or a notification, shows the window again.
- Window size and position, and the zoom level (Cmd+= / Cmd+- / Cmd+0, 50% to 300%), are remembered.
- If the web content process crashes, the page reloads.

## Implementation

- `ChatWindowController.windowShouldClose` calls `orderOut` and returns `false`.
- `applicationShouldTerminateAfterLastWindowClosed` returns `false`;
  `applicationShouldHandleReopen` shows the window.
- `AppDelegate` starts a `ProcessInfo` activity (`.userInitiatedAllowingIdleSystemSleep`) for the app's
  lifetime, which disables App Nap but allows the Mac to sleep.
- WebKit's page-visibility process suppression is disabled through a private preference
  ([ADR 0004](../adr/0004-keep-web-view-active-in-background.md)).
- Window frame autosave name `MainWindow`; zoom in `UserDefaults` key `pageZoom`.

## Menu

App, Edit, View and Window menus are built in code (`MainMenu`). The Edit menu is required: without it,
copy and paste do not work in the web view. View has Reload (Cmd+R), Go to Start (Cmd+Shift+H),
Back/Forward (Cmd+[ / Cmd+]), zoom, and full screen (Ctrl+Cmd+F).
