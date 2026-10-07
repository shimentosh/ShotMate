// Generates ShotMate's app icon as an .iconset folder (convert with `iconutil`).
// Usage: swift Scripts/make-icon.swift <output.iconset>
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: 1024, height: 1024)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // macOS icon grid: 824pt rounded square centred in a 1024pt canvas.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(
        starting: NSColor(srgbRed: 0.30, green: 0.56, blue: 1.00, alpha: 1),
        ending: NSColor(srgbRed: 0.38, green: 0.27, blue: 0.95, alpha: 1)
    )?.draw(in: shape, angle: -90)

    // Viewfinder corners.
    let frame = tile.insetBy(dx: 190, dy: 190)
    let arm: CGFloat = 130
    NSColor.white.setStroke()
    let corners = NSBezierPath()
    corners.lineWidth = 56
    corners.lineCapStyle = .round
    corners.lineJoinStyle = .round
    for (corner, dx, dy) in [
        (NSPoint(x: frame.minX, y: frame.maxY), arm, -arm),
        (NSPoint(x: frame.maxX, y: frame.maxY), -arm, -arm),
        (NSPoint(x: frame.minX, y: frame.minY), arm, arm),
        (NSPoint(x: frame.maxX, y: frame.minY), -arm, arm)
    ] {
        corners.move(to: NSPoint(x: corner.x, y: corner.y + dy))
        corners.line(to: corner)
        corners.line(to: NSPoint(x: corner.x + dx, y: corner.y))
    }
    corners.stroke()

    // Small dot in the centre: the "shot".
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 512 - 52, y: 512 - 52, width: 104, height: 104)).fill()

    return rep.representation(using: .png, properties: [:])
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
        try drawIcon(pixels: size * scale)?.write(to: output.appendingPathComponent(name))
    }
}
