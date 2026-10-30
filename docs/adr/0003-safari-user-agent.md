# 0003. Present the web view as Safari

Date: 2026-10-30. Status: accepted.

## Context

Google blocks sign-in from embedded browsers it detects through the user agent. A plain `WKWebView`
user agent lacks the `Version/... Safari/...` part.

## Decision

Set `customUserAgent` to a current Safari for macOS user agent (`LinkPolicy.userAgent`), also used for
avatar downloads.

## Consequences

- Sign-in works and Chat serves the same UI as in Safari.
- The version in the string should be bumped occasionally so Google does not treat it as outdated.
