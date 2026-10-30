# 0007. English as development language, app follows the system language

Date: 2026-10-30. Status: accepted.

## Context

The project started in Dutch. The repository is public on GitHub, so English is more accessible, while
the main user runs macOS in Dutch.

## Decision

Code, comments, logs, docs, release notes and commit messages are in English. The app's own UI uses
`NSLocalizedString` with English keys and ships a Dutch translation; macOS picks the language.

## Consequences

- Commits before 1.1.0 keep their Dutch messages; history is not rewritten.
- Every new user-facing string needs a Dutch translation (see [localization spec](../specs/localization.md)).
