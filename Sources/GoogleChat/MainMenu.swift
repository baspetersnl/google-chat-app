// Google Chat voor macOS
// Copyright (C) 2026 Bas Peters
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
// even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License along with this program. If not,
// see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

/// Bouwt de menubalk. Zonder Bewerk-menu werken kopiëren en plakken niet in de webview.
@MainActor
enum MainMenu {
    static func build() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenu(appMenu()))
        menu.addItem(submenu(editMenu()))
        menu.addItem(submenu(viewMenu()))
        menu.addItem(submenu(windowMenu()))
        return menu
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }

    private static func item(_ title: String, _ action: Selector?, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "Google Chat")
        menu.addItem(item("Over Google Chat", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Verberg Google Chat", #selector(NSApplication.hide(_:)), "h"))
        menu.addItem(item("Verberg andere", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        menu.addItem(item("Toon alles", #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Stop Google Chat", #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Wijzig")
        menu.addItem(item("Herstel", Selector(("undo:")), "z"))
        menu.addItem(item("Opnieuw", Selector(("redo:")), "z", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Knip", #selector(NSText.cut(_:)), "x"))
        menu.addItem(item("Kopieer", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Plak", #selector(NSText.paste(_:)), "v"))
        menu.addItem(item("Plak met zelfde stijl", #selector(NSTextView.pasteAsPlainText(_:)), "v", [.command, .option, .shift]))
        menu.addItem(item("Selecteer alles", #selector(NSText.selectAll(_:)), "a"))
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "Weergave")
        menu.addItem(item("Herlaad", #selector(ChatWindowController.reloadPage(_:)), "r"))
        menu.addItem(item("Ga naar start", #selector(ChatWindowController.goHome(_:)), "h", [.command, .shift]))
        menu.addItem(item("Terug", #selector(ChatWindowController.goBack(_:)), "["))
        menu.addItem(item("Vooruit", #selector(ChatWindowController.goForward(_:)), "]"))
        menu.addItem(.separator())
        menu.addItem(item("Werkelijke grootte", #selector(ChatWindowController.resetZoom(_:)), "0"))
        menu.addItem(item("Zoom in", #selector(ChatWindowController.zoomIn(_:)), "="))
        menu.addItem(item("Zoom uit", #selector(ChatWindowController.zoomOut(_:)), "-"))
        menu.addItem(.separator())
        menu.addItem(item("Schermvullende weergave", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Venster")
        menu.addItem(item("Minimaliseer", #selector(NSWindow.performMiniaturize(_:)), "m"))
        menu.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))
        menu.addItem(item("Sluit venster", #selector(NSWindow.performClose(_:)), "w"))
        NSApp.windowsMenu = menu
        return menu
    }
}
