# 0004. Keep the web view active while hidden

Date: 2026-10-30. Status: accepted.

## Context

Notifications only arrive when Chat's page keeps running while the window is hidden. macOS App Nap and
WebKit's page-visibility-based process suppression both throttle hidden pages heavily.

## Decision

- Closing the window hides it instead of closing it.
- Hold a `ProcessInfo` activity with `.userInitiatedAllowingIdleSystemSleep` for the app's lifetime.
- Disable WebKit's process suppression through the private `WKPreferences` setting
  `pageVisibilityBasedProcessSuppressionEnabled`, set via KVC only when
  `_setPageVisibilityBasedProcessSuppressionEnabled:` exists.

## Consequences

- Messages and notifications keep arriving with the window hidden.
- Slightly higher energy use than a fully napped app; the Mac can still sleep.
- The private setting may disappear in a future WebKit. The guard makes the app ignore it then; the
  symptom would be late notifications while hidden.
- Private API use rules out the Mac App Store, which is not a goal.
