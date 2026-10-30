# Localization

Status: implemented in 1.1.0.

## Behaviour

- The app's own texts (menus, buttons, permission prompts, About window) follow the macOS language.
- Supported: English (development language) and Dutch. Any other language falls back to English.
- Google Chat's own interface is not affected; its language follows the Google account.

## Implementation

- `CFBundleDevelopmentRegion` is `en`; `CFBundleLocalizations` lists `en` and `nl`.
- Code uses `NSLocalizedString` with the **English text as key** (for example in `MainMenu.localized`).
  `Support/en.lproj/Localizable.strings` is intentionally empty.
- `Support/<lang>.lproj/InfoPlist.strings` translates `NSCameraUsageDescription`,
  `NSMicrophoneUsageDescription` and `NSHumanReadableCopyright`.
- `scripts/build.sh` copies `Support/*.lproj` into `Contents/Resources/`.
- Full screen uses the title "Enter Full Screen"; AppKit updates it to "Exit Full Screen" itself.

## Adding a language

1. Create `Support/<lang>.lproj/` with translated copies of `nl.lproj/Localizable.strings` and
   `InfoPlist.strings`.
2. Add `<lang>` to `CFBundleLocalizations` in `Support/Info.plist`.
3. Optionally extend the unread label patterns in `UnreadCount` and `UnreadShim` (see
   [unread-badge.md](unread-badge.md)), which are matched against Chat's language, not the app's.

## Verification

Resolve keys from the built bundle per preferred language with `Bundle.preferredLocalizations`.
On 2026-10-30: `nl` → "Stop Google Chat", `en` → "Quit Google Chat", `de` → English fallback.
