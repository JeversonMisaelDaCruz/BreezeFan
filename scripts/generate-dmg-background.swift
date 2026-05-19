#!/usr/bin/env swift
//
// generate-dmg-background.swift — renders Resources/dmg-background.png
//
// Output:   Resources/dmg-background.png (1200×760 sRGB PNG, @2x of 600×380)
// Run:      swift scripts/generate-dmg-background.swift
//           swift scripts/generate-dmg-background.swift <custom-output-path>
//
// Why a Swift CG script and not a Sketch / Figma export:
// - Reproducible: any contributor regenerates the same PNG from a fresh checkout.
// - Version-string aware: the watermark reads CFBundleShortVersionString from
//   App/Info.plist at render time so the DMG identifies itself.
// - Repo size: ~80 KB PNG instead of a multi-MB Sketch file.
//
// Layout (all values in @2x pixel coords):
//
//     ┌──────────────────────── 1200 ─────────────────────────┐
//     │                                                       │ ▲
//     │                       BreezeFan                       │ │
//     │             Fan control for Apple Silicon             │ │
//     │                                                       │ │
//     │   ┌────┐                                  ┌────┐      │ 760
//     │   │app │              ─────►              │/Apps│      │ │
//     │   └────┘                                  └────┘      │ │
//     │                                                       │ │
//     │           Drag BreezeFan to Applications              │ │
//     │                                       v0.7.0          │ │
//     └───────────────────────────────────────────────────────┘ ▼
//

import Cocoa
import Foundation

// MARK: - Output path

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/dmg-background.png"

// MARK: - Helpers

func readBundleVersion() -> String {
    let path = "App/Info.plist"
    guard let data = FileManager.default.contents(atPath: path),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let version = plist["CFBundleShortVersionString"] as? String else {
        // Fallback — keeps the render reproducible if Info.plist drifts.
        return "0.0.0"
    }
    return version
}

func srgb(_ r: Int, _ g: Int, _ b: Int, alpha: CGFloat = 1.0) -> NSColor {
    NSColor(srgbRed: CGFloat(r) / 255.0,
            green:   CGFloat(g) / 255.0,
            blue:    CGFloat(b) / 255.0,
            alpha:   alpha)
}

// MARK: - Render

let imageSize = NSSize(width: 1200, height: 760)

// Render into a fixed-pixel bitmap rep so the output is exactly 1200×760 even
// when this script runs on a Retina display. `NSImage.lockFocus()` would
// silently scale to backing-store resolution (e.g. 2400×1520 @2x).
guard let bitmapRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(imageSize.width),
    pixelsHigh: Int(imageSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("✗ Failed to allocate bitmap rep\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
guard let ctx = NSGraphicsContext.current?.cgContext else {
    FileHandle.standardError.write(Data("✗ Failed to acquire CG context\n".utf8))
    exit(1)
}

// 1. Solid graphite background (FCTheme.bgGraphiteBottom)
srgb(0x0f, 0x10, 0x13).setFill()
NSRect(origin: .zero, size: imageSize).fill()

// 2. Soft accent-blue radial blob (top-right, echoes FCWallpaper aesthetic)
ctx.saveGState()
let blobColors: [CGColor] = [
    srgb(0x3b, 0x82, 0xf6, alpha: 0.25).cgColor,
    srgb(0x3b, 0x82, 0xf6, alpha: 0.00).cgColor,
]
if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: blobColors as CFArray,
                              locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(gradient,
                           startCenter: CGPoint(x: 1000, y: 620), startRadius: 0,
                           endCenter:   CGPoint(x: 1000, y: 620), endRadius: 420,
                           options: [])
}
ctx.restoreGState()

// 3. Secondary cyan blob (bottom-left)
ctx.saveGState()
let blob2Colors: [CGColor] = [
    srgb(0x06, 0xb6, 0xd4, alpha: 0.18).cgColor,
    srgb(0x06, 0xb6, 0xd4, alpha: 0.00).cgColor,
]
if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: blob2Colors as CFArray,
                              locations: [0.0, 1.0]) {
    ctx.drawRadialGradient(gradient,
                           startCenter: CGPoint(x: 220, y: 140), startRadius: 0,
                           endCenter:   CGPoint(x: 220, y: 140), endRadius: 360,
                           options: [])
}
ctx.restoreGState()

// Helper: centered text draw at a given Y (measured from bottom of image)
func drawCentered(_ text: String, font: NSFont, color: NSColor, yFromBottom: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let textSize = attributed.size()
    let x = (imageSize.width - textSize.width) / 2
    attributed.draw(at: NSPoint(x: x, y: yFromBottom))
}

// 4. Title — "BreezeFan" 38pt semibold @1x = 76pt @2x
drawCentered("BreezeFan",
             font: NSFont.systemFont(ofSize: 76, weight: .semibold),
             color: NSColor(white: 1.0, alpha: 0.95),
             yFromBottom: 760 - 96 - 76)  // 96 = top padding @2x

// 5. Tagline — 13pt regular @1x = 26pt @2x
drawCentered("Fan control for Apple Silicon",
             font: NSFont.systemFont(ofSize: 26, weight: .regular),
             color: NSColor(white: 1.0, alpha: 0.55),
             yFromBottom: 760 - 200)

// 6. Arrow between the icon spots — icons land at (150,190) and (450,190) in @1x
//    bottom-origin coords → (300, 380) and (900, 380) in @2x bottom-origin.
//    Draw the arrow horizontally at y=380, spanning x=480..720.
ctx.saveGState()
ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.35).cgColor)
ctx.setLineWidth(3)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: 470, y: 380))
ctx.addLine(to: CGPoint(x: 730, y: 380))
ctx.strokePath()
// Chevron tip
ctx.move(to: CGPoint(x: 710, y: 402))
ctx.addLine(to: CGPoint(x: 732, y: 380))
ctx.addLine(to: CGPoint(x: 710, y: 358))
ctx.strokePath()
ctx.restoreGState()

// 7. Hint — 11pt regular @1x = 22pt @2x, near the bottom
drawCentered("Drag BreezeFan to Applications",
             font: NSFont.systemFont(ofSize: 22, weight: .regular),
             color: NSColor(white: 1.0, alpha: 0.45),
             yFromBottom: 130)

// 8. Version watermark — bottom-right at 9pt @1x = 18pt @2x
let version = readBundleVersion()
let verAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
    .foregroundColor: NSColor(white: 1.0, alpha: 0.25),
]
let verText = NSAttributedString(string: "v\(version)", attributes: verAttrs)
let verSize = verText.size()
verText.draw(at: NSPoint(x: imageSize.width - verSize.width - 40, y: 40))

NSGraphicsContext.restoreGraphicsState()

// MARK: - Encode + write

guard let png = bitmapRep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("✗ Failed to encode PNG\n".utf8))
    exit(1)
}

let outURL = URL(fileURLWithPath: outputPath)
do {
    try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try png.write(to: outURL)
} catch {
    FileHandle.standardError.write(Data("✗ Write failed: \(error)\n".utf8))
    exit(1)
}

print("✓ Wrote \(outputPath) (1200×760 @2x, v\(version))")
