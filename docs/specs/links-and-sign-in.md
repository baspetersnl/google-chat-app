# Links, sign-in, uploads and downloads

Status: implemented in 1.0.0, verified working on 2026-10-30.

## Behaviour

- Google Chat and the Google sign-in flow stay inside the app.
- Links to anything else (Drive, Docs, Meet, websites) open in the default browser.
- `mailto:`, `tel:`, `facetime:`, `zoommtg:` and `msteams:` links open in their system handler.
- Attachments can be uploaded through the standard file dialog (multiple files and folders when the page
  allows it). Downloads go to `~/Downloads` with a unique name (`file (1).pdf`), and the Downloads stack
  in the Dock bounces when done.
- Camera and microphone requests from `*.google.com` are granted (macOS still asks once per app).
- JavaScript `alert()` and `confirm()` show native alerts.

## Rules (`LinkPolicy.isInternal`)

A URL stays in the app when its host is:

- `chat.google.com`;
- `mail.google.com` with a path starting with `/chat`;
- `workspace.google.com` (landing page for signed-out users) or `accounts.youtube.com`;
- `accounts.google.*`, `www.google.com/accounts...`, or any Google domain with `/accounts/SetSID`
  (cookie hand-off to country domains such as `google.nl`).

Applied as follows:

- main-frame **link clicks** to non-internal web URLs open in the browser; other navigations (redirects,
  form posts) are always allowed, which keeps the sign-in flow intact;
- `target="_blank"` and `window.open(url)`: internal URLs load in the main web view, others open in the
  browser;
- `window.open()` without a URL gets an invisible `PopupCatcher` web view; its first real URL is routed
  the same way.

## Sign-in

- The web view uses a Safari user agent so Google does not reject it as an embedded browser
  ([ADR 0003](../adr/0003-safari-user-agent.md)).
- Signed out, `chat.google.com` redirects to `accounts.google.com/ServiceLogin?service=dynamite...`.
- In the first version, clicking "Sign in" opened the browser, because the flow went through a host or
  popup that was not internal. Allowing the hosts above and loading internal popups in the main view
  fixed it. Every URL sent to the browser is logged as `Opened externally: <url>` to diagnose regressions.
- Cookies live in the default `WKWebsiteDataStore`, tied to the bundle identifier.
