// Generates AppIcon.png at 1024×1024 using Core Graphics direct (no SwiftUI ImageRenderer).
// Run: swift scripts/generate-icon.swift <output.png>
import AppKit
import CoreGraphics

guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift scripts/generate-icon.swift <output.png>")
    exit(2)
}
let outputPath = CommandLine.arguments[1]
let size: CGFloat = 1024
let cornerRadius: CGFloat = 224

// Create bitmap context
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("✗ failed to create CGContext")
    exit(1)
}

// Helper: rounded rect path
func roundedRectPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

let bounds = CGRect(x: 0, y: 0, width: size, height: size)
let bgPath = roundedRectPath(bounds, cornerRadius)

// Background gradient (top-left blue → bottom-right purple → graphite)
context.saveGState()
context.addPath(bgPath)
context.clip()

let gradColors: CFArray = [
    CGColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0),  // accent blue
    CGColor(red: 0.42, green: 0.27, blue: 0.92, alpha: 1.0),  // purple
    CGColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1.0),  // graphite
] as CFArray
let gradLocations: [CGFloat] = [0.0, 0.55, 1.0]

guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: gradLocations) else {
    print("✗ gradient failed")
    exit(1)
}

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),       // top-left in CG (flipped Y)
    end:   CGPoint(x: size, y: 0),       // bottom-right
    options: []
)
context.restoreGState()

// Inner stroke
context.saveGState()
context.addPath(roundedRectPath(bounds.insetBy(dx: 2, dy: 2), cornerRadius - 2))
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
context.setLineWidth(4)
context.strokePath()
context.restoreGState()

// Render flame SF Symbol via NSImage rasterization (test icon for v0.2.0 update flow).
let cfg = NSImage.SymbolConfiguration(pointSize: 620, weight: .semibold)
guard let fanImage = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else {
    print("✗ Cannot load flame.fill SF Symbol")
    exit(1)
}

// Tint the symbol white
let tintedImage = NSImage(size: fanImage.size, flipped: false) { rect in
    fanImage.draw(in: rect)
    NSColor.white.set()
    rect.fill(using: .sourceIn)
    return true
}

guard let cgFan = tintedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("✗ cgImage from fan failed")
    exit(1)
}

let fanSize = tintedImage.size
let fanRect = CGRect(
    x: (size - fanSize.width) / 2,
    y: (size - fanSize.height) / 2,
    width: fanSize.width,
    height: fanSize.height
)

// Soft shadow
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -12),
    blur: 30,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
)
context.draw(cgFan, in: fanRect)
context.restoreGState()

// Extract image and write PNG
guard let cgImage = context.makeImage() else {
    print("✗ makeImage failed")
    exit(1)
}
let bitmap = NSBitmapImageRep(cgImage: cgImage)
bitmap.size = NSSize(width: size, height: size)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    print("✗ PNG encoding failed")
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
do {
    try data.write(to: url)
    print("✓ Wrote \(outputPath) (\(data.count) bytes)")
} catch {
    print("✗ \(error)")
    exit(1)
}
