// Google Chat for macOS
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

/// Builds the menu bar. Without an Edit menu, copy and paste do not work in the web view.
/// Titles are in English and translated through Localizable.strings into the system language.
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

    private static func localized(_ title: String) -> String {
        NSLocalizedString(title, comment: "Menu item")
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }

    private static func titledMenu(_ title: String) -> NSMenu {
        NSMenu(title: localized(title))
    }

    private static func item(_ title: String, _ action: Selector?, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: localized(title), action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "Google Chat")
        menu.addItem(item("About Google Chat", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Hide Google Chat", #selector(NSApplication.hide(_:)), "h"))
        menu.addItem(item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        menu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Quit Google Chat", #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = titledMenu("Edit")
        menu.addItem(item("Undo", Selector(("undo:")), "z"))
        menu.addItem(item("Redo", Selector(("redo:")), "z", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        menu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        menu.addItem(item("Paste and Match Style", #selector(NSTextView.pasteAsPlainText(_:)), "v", [.command, .option, .shift]))
        menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = titledMenu("View")
        menu.addItem(item("Reload Page", #selector(ChatWindowController.reloadPage(_:)), "r"))
        menu.addItem(item("Go to Start", #selector(ChatWindowController.goHome(_:)), "h", [.command, .shift]))
        menu.addItem(item("Back", #selector(ChatWindowController.goBack(_:)), "["))
        menu.addItem(item("Forward", #selector(ChatWindowController.goForward(_:)), "]"))
        menu.addItem(.separator())
        menu.addItem(item("Actual Size", #selector(ChatWindowController.resetZoom(_:)), "0"))
        menu.addItem(item("Zoom In", #selector(ChatWindowController.zoomIn(_:)), "="))
        menu.addItem(item("Zoom Out", #selector(ChatWindowController.zoomOut(_:)), "-"))
        menu.addItem(.separator())
        menu.addItem(item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = titledMenu("Window")
        menu.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"))
        menu.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))
        menu.addItem(item("Close Window", #selector(NSWindow.performClose(_:)), "w"))
        NSApp.windowsMenu = menu
        return menu
    }
}
