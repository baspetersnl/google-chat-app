# Google Chat voor macOS

Native macOS-app (Swift, AppKit en WKWebView) rond Google Chat, als vervanging van de Chrome-extensie.

## Bouwen

Je hebt alleen de Command Line Tools nodig, geen Xcode.

```sh
./scripts/build.sh           # bouwt build/Google Chat.app
./scripts/build.sh install   # bouwt en kopieert naar /Applications
```

## Wat de app doet

- **Notificaties**: WKWebView kent de Web Notification API niet. `NotificationShim` vervangt
  `window.Notification` (en `showNotification` van service workers) en stuurt elke notificatie naar
  `NotificationBridge`, die hem via het macOS Notification Center toont, met de avatar van de afzender.
  Klik je op een notificatie, dan gaat de app naar voren en opent Chat het juiste gesprek.
- **Op de achtergrond actief**: Cmd+W verbergt het venster alleen. App Nap en de vertraging van
  verborgen pagina's staan uit, zodat berichten binnen blijven komen. Stoppen gaat met Cmd+Q.
- **Dock-badge** met het aantal ongelezen berichten, gelezen van de Home-snelkoppeling in Chat.
  Is er geen aantal maar wel een favicon met stip, dan toont de badge een stip.
- **Gesprek onderaan na versturen**: in WebKit verschuift een gesprek na het versturen naar het
  een-na-laatste bericht. `ScrollShim` houdt het gesprek onderaan.
- **Links** buiten Chat (Drive, Meet, websites) openen in je standaardbrowser.
- **Bijlagen** uploaden via het bestandsvenster en downloaden naar `~/Downloads`.
- Inloggen blijft bewaard, zoomniveau (Cmd+/Cmd-/Cmd0) en vensterpositie ook.

## Testen en debuggen

De webview is inspecteerbaar: Safari > Ontwikkel > Google Chat. Een testnotificatie vanuit de console:

```js
new Notification('Test', { body: 'Hallo vanuit Google Chat' })
```

Komt er niets binnen, kijk dan in Systeeminstellingen > Berichtgeving > Google Chat of meldingen
aanstaan, en in Chat zelf (Instellingen > Meldingen) of meldingen voor de browser aanstaan.

## Structuur

| Bestand | Rol |
| --- | --- |
| `AppDelegate.swift` | Opstarten, heropenen via Dock, App Nap uitzetten |
| `ChatWindowController.swift` | Venster, webview, navigatie, uploads, dock-badge |
| `NotificationShim.swift` | JavaScript dat de Notification API nabootst |
| `NotificationBridge.swift` | Brug naar UNUserNotificationCenter; bij een klik het juiste gesprek openen |
| `UnreadShim.swift`, `UnreadTracker.swift`, `UnreadCount.swift` | Ongelezen-status uitlezen voor de Dock-badge |
| `ScrollShim.swift` | Gesprek onderaan houden na versturen |
| `LinkPolicy.swift` | Welke URL's in de app blijven |
| `PopupCatcher.swift` | `window.open()` zonder URL naar de browser sturen |
| `DownloadManager.swift` | Downloads naar `~/Downloads` |
| `MainMenu.swift` | Menubalk (nodig voor kopiëren en plakken) |

## Licentie

Copyright (C) 2026 Bas Peters

Dit project valt onder de [GNU General Public License v3.0](LICENSE). Je mag de code gebruiken,
aanpassen en verspreiden, zolang afgeleide versies onder dezelfde licentie vallen en de broncode
beschikbaar blijft.

Deze app is niet gemaakt door of verbonden aan Google. "Google Chat" is een handelsmerk van Google LLC.
