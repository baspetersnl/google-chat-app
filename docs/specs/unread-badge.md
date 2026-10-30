# Unread badge

Status: implemented in 1.0.0, verified working on 2026-10-30.

## Behaviour

- The Dock icon shows the number of unread messages, matching the count Chat shows on its Home shortcut.
- When no number can be found but Chat signals unread messages through its favicon, the badge shows `•`.
- Without unread messages, the badge is empty.

## Implementation

`UnreadShim` (all frames) reports per frame, at most once per second and only on change, to the
`gchatUnread` handler: a random frame id, URL, `document.title`, favicon URLs and the distinct
`aria-label`s that contain `unread` or `ongelezen` (max 50).

`UnreadTracker` keeps the latest state per frame id (reset on every main-frame `didCommit`) and computes
the badge with `UnreadCount`:

1. count from the title (`(3)` or `3 unread`), taking the maximum across frames;
2. count from labels: the number in the **Home shortcut** label if present, otherwise the highest
   `<n> unread` number in any label; labels without a number are ignored;
3. badge = the higher of 1 and 2; if that is 0 and a favicon URL matches `(?<!no_)dot|notif|unread|badge`, `•`.

## Observed Chat behaviour (2026-10-30, Dutch UI)

- The page title is just `Chat`; it never contains a count. (This was the first, failed approach.)
- Relevant labels: `Snelkoppeling Home, 1 ongelezen bericht` (Home shortcut, the total) and
  `1 ongelezen bericht`.
- Noise labels that must not be counted: `Filter Ongelezen aan-/uitzetten`, `Ongelezen`,
  `Markeren als ongelezen`. Counting every matching label gave 5 instead of 1.
- Favicon without unread messages:
  `https://ssl.gstatic.com/dynamite/images/favicons_20260602/chat_2026_logo_favicon_no_dot_64px.png`.
  The variant with unread messages was not observed; a name containing `dot` without `no_` is assumed.
- Many third-party frames (feedback, contacts hovercard, Workspace side panel, account cookie rotation)
  also report; they have no labels and are ignored by the computation.

## Known limitations

- Counts are only parsed for English and Dutch labels. Chat's language follows the Google account, not
  macOS; in other languages the badge falls back to the favicon dot.
- The badge is set by the app, not by Notification Center (`badge` authorization is requested but unused).
