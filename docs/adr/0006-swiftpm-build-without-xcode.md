# 0006. Build with SwiftPM and assemble the bundle by script

Date: 2026-10-30. Status: accepted.

## Context

Only the Command Line Tools are installed, not Xcode. An `.app` bundle with an `Info.plist` and a code
signature is needed for notifications and permission prompts.

## Decision

Use a Swift package with one executable target. `scripts/build.sh` builds it, assembles the bundle
(binary, `Info.plist`, icon, `*.lproj`) and ad-hoc signs it. The icon is drawn in code
(`scripts/make-icon.swift`). The build uses `--build-system native`, because the default SwiftPM build
system failed here with "Unknown error parsing property list".

## Consequences

- No Xcode needed; the build is reproducible from the command line.
- `--build-system native` is deprecated and prints warnings. When it is removed, retry the default build
  system or move to an Xcode project.
- Ad-hoc signing means no notarization; see [build and release](../specs/build-and-release.md).
