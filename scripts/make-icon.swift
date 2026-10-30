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

// Draws the app icon (1024x1024 PNG): a green rounded tile with a white speech bubble.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let size: CGFloat = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Tile following the macOS icon grid: 824px with a 100px margin.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 24
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor(srgbRed: 0.0, green: 0.55, blue: 0.27, alpha: 1).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(
    starting: NSColor(srgbRed: 0.13, green: 0.73, blue: 0.40, alpha: 1),
    ending: NSColor(srgbRed: 0.0, green: 0.55, blue: 0.27, alpha: 1)
)!.draw(in: tilePath, angle: -90)

// Speech bubble with a tail at the bottom left.
let bubble = NSBezierPath(roundedRect: NSRect(x: 262, y: 360, width: 500, height: 360), xRadius: 90, yRadius: 90)
let tail = NSBezierPath()
tail.move(to: NSPoint(x: 300, y: 400))
tail.line(to: NSPoint(x: 262, y: 270))
tail.line(to: NSPoint(x: 420, y: 370))
tail.close()

NSColor.white.setFill()
bubble.fill()
tail.fill()

// Three dots in the bubble.
NSColor(srgbRed: 0.0, green: 0.55, blue: 0.27, alpha: 1).setFill()
for x in [382.0, 512.0, 642.0] {
    NSBezierPath(ovalIn: NSRect(x: x - 38, y: 502, width: 76, height: 76)).fill()
}

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: output))
