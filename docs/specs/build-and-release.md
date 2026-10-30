# Build and release

Status: in use since 1.0.0.

## Build (`scripts/build.sh`)

1. `swift build -c release --build-system native` ([ADR 0006](../adr/0006-swiftpm-build-without-xcode.md)).
2. Generate the icon once: `scripts/make-icon.swift` draws a 1024 px PNG, `sips` makes the iconset
   sizes, `iconutil` creates `build/AppIcon.icns` (cached; delete it to regenerate).
3. Assemble `build/Google Chat.app`: binary, `Info.plist`, icon, `*.lproj`.
4. Ad-hoc sign with `codesign --force --sign -`. Required for notifications and camera/microphone
   permissions to work.
5. With `install`: replace `/Applications/Google Chat.app`.

## Release (`scripts/release.sh`)

1. Bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `Support/Info.plist`, commit, push.
2. Run `./scripts/release.sh`. It refuses to run with uncommitted changes or an existing tag, then
   builds, zips with `ditto -c -k --keepParent` (keeps the signature), writes English release notes to
   `build/release-notes-<version>.md`, creates and pushes the annotated tag `v<version>`, and publishes
   the GitHub release with `gh` when it is installed and authenticated.

Release history: `v1.0.0` (first release), `v1.1.0` (English project, localized app), `v1.1.1` (bundle identifier `nl.baspeters.googlechat`).

## Distribution limits

- Ad-hoc signed, not notarized: Gatekeeper blocks downloaded builds until the user chooses
  "Open Anyway" or removes the quarantine attribute. The release notes explain both.
- Notarization needs an Apple Developer account and a Developer ID certificate; not set up.
- Builds are arm64 only (the architecture of the build machine).
