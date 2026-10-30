# 0001. Wrap Google Chat in a WKWebView

Date: 2026-10-30. Status: accepted.

## Context

The goal is a native macOS replacement for the Google Chat Chrome extension, with working notifications.
Google offers no public Chat client API suitable for a full client, and rebuilding the Chat UI is out of scope.

## Decision

Load `https://chat.google.com` in a single `WKWebView` inside a native AppKit window, and add native
behaviour (notifications, Dock badge, background activity, links, downloads) around it with Swift and
injected JavaScript.

## Consequences

- Small codebase, no dependencies, Chat features work as on the web.
- Features rely on undocumented Chat behaviour (data formats, DOM attributes, labels, favicon names)
  that can change without notice. Specs record what was observed; logs help diagnose breakage.
- WebKit differs from Chrome in places (see [0005](0005-pin-scroll-position.md)).
- Electron was not considered: it would add ~150 MB and a Node toolchain for the same web content.
