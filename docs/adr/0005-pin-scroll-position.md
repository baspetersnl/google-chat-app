# 0005. Pin the conversation to the bottom instead of fixing the root cause

Date: 2026-10-30. Status: accepted.

## Context

In WebKit, a conversation ends at the second-to-last message after sending with Enter. Measurements
showed Chat scrolls to the bottom correctly, and about 500 ms later the list moves up ~54 px without any
scroll API call. Disabling scroll anchoring (`overflow-anchor: none`) did not help. The shift coincides
with Chat focusing and shrinking the composer; the exact WebKit cause was not found.

## Decision

Inject `ScrollShim`, which tracks whether the user or Chat intended a scroll, keeps lists that were at
the bottom pinned there when they shift without intent, and for 2 seconds after Enter ignores Chat's own
programmatic scrolls. Scroll anchoring is left at its default.

## Consequences

- The conversation stays at the bottom after sending (verified).
- It is a symptom fix: if Chat or WebKit changes, the shim may become unnecessary or need adjusting.
- It touches every scrollable element in the page; user scrolling always wins.
- Sending with the send button is not covered by the 2-second window.
