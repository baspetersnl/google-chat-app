# Unread badge

Status: implemented in 1.0.0, verified working on 2026-10-30.

## Behaviour

- The Dock icon shows the number of unread messages, matching the count Chat shows on its Home shortcut.
- When no number can be found but Chat signals unread messages through its favicon, the badge shows `•`.
- Without unread messages, the badge is empty.

## Implementation

`UnreadShim` (all frames) reports per frame, at most once per second and only on change, to the
`gchatUnread` handler: a random frame id, URL, `document.title`, favicon URLs and the distinct
`aria-label`s that contain `unread` or `ongelezen` (max 50). It also sends a heartbeat with the full state
every 30 seconds and a final `gone` message on `pagehide`.

`UnreadTracker` keeps the latest state per frame id and computes
the badge with `UnreadCount`:

1. count from the title (`(3)` or `3 unread`), taking the maximum across frames;
2. count from labels: the number in the **Home shortcut** label if present, otherwise the highest
   `<n> unread` number in any label; labels without a number are ignored;
3. badge = the higher of 1 and 2; if that is 0 and a favicon URL matches `(?<!no_)dot|notif|unread|badge`, `•`.

A frame's state is dropped when the frame sends `{ frame, gone: true }` on `pagehide`, and all states are
dropped on every main-frame `didCommit`. Without this, a reloaded or removed frame kept its last count,
and because the badge takes the maximum across frames, the badge stayed up after the messages were read.

Frames from subframes that stay silent for 120 seconds are removed (logged as `Unread frame removed`),
because removing an iframe does not let it report that it is gone. The main frame is never pruned by
timeout: it holds the Home shortcut. At most 50 frames are kept. `SuspendingClock` is used for the
timeout, so waking the Mac does not discard every frame. The badge is recomputed after every prune.

A heartbeat from a known frame only refreshes when the frame was last heard from; it never replaces the
stored state. A heartbeat from an unknown frame adds that frame back (logged as `Unread frame restored`).
That happens when WebKit throttled the frame's timers past the timeout (subframes, hidden page), or when
a page comes back from the back/forward cache after its `gone` message. Without it the frame would stay
missing, because the shim only reports changes.

Every badge change is logged as `Unread badge: <old> -> <new> (frames=<n>)`.

## Observed Chat behaviour (2026-10-30, Dutch UI)

- The page title is just `Chat`; it never contains a count. (This was the first, failed approach.)
- Relevant labels: `Snelkoppeling Home, 1 ongelezen bericht` (Home shortcut, the total) and
  `1 ongelezen bericht`.
- Noise labels that must not be counted: `Filter Ongelezen aan-/uitzetten`, `Ongelezen`,
  `Markeren als ongelezen`. Counting every matching label gave 5 instead of 1.
- Favicon without unread messages:
  `https://ssl.gstatic.com/dynamite/images/favicons_20260602/chat_2026_logo_favicon_no_dot_64px.png`.
  On 2026-11-04 the favicon stayed `..._no_dot_...` while Home reported 3 unread messages, so the
  favicon cannot be used to correct the label count. A variant with a dot was still not observed; a
  name containing `dot` without `no_` is assumed.
- The Home total includes unread thread replies, which are easy to miss in the conversation list.
  Observed 2026-11-04: Home said `1 ongelezen bericht` after both visible messages were read; the
  space showed `Gespreksthread, 1 ongelezen gesprek`, and the count went to 0 once that thread was
  read. A badge that stays at 1 is therefore usually a real unread thread, not a stale frame.
- Many third-party frames (feedback, contacts hovercard, Workspace side panel, account cookie rotation)
  also report; they have no labels and are ignored by the computation.

## Known limitations

- Counts are only parsed for English and Dutch labels. Chat's language follows the Google account, not
  macOS; in other languages the badge falls back to the favicon dot.
- The badge is set by the app, not by Notification Center (`badge` authorization is requested but unused).
