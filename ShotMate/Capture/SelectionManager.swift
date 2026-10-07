import AppKit

enum SelectionHandle: CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    /// Position on `rect` in flipped (top-left origin) coordinates.
    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
        case .top: CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
        case .right: CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
        case .left: CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft: true
        default: false
        }
    }

    var cursor: NSCursor {
        if #available(macOS 15.0, *) {
            let position: NSCursor.FrameResizePosition = switch self {
            case .topLeft: .topLeft
            case .top: .top
            case .topRight: .topRight
            case .right: .right
            case .bottomRight: .bottomRight
            case .bottom: .bottom
            case .bottomLeft: .bottomLeft
            case .left: .left
            }
            return .frameResize(position: position, directions: .all)
        }
        switch self {
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        default: return .crosshair
        }
    }
}

/// Geometry for the capture selection: creating, moving, resizing and hit-testing.
/// All rects are in the overlay's flipped point coordinates and snapped to whole points.
struct SelectionManager {
    let bounds: CGRect
    private(set) var rect: CGRect?

    static let minimumSize: CGFloat = 4
    private static let handleHitRadius: CGFloat = 9
    private static let edgeHitTolerance: CGFloat = 4

    init(bounds: CGRect) {
        self.bounds = bounds
    }

    mutating func set(_ newRect: CGRect?) {
        rect = newRect.map(normalized)
    }

    mutating func clear() {
        rect = nil
    }

    func rect(from anchor: CGPoint, to point: CGPoint) -> CGRect {
        normalized(CGRect(
            x: min(anchor.x, point.x), y: min(anchor.y, point.y),
            width: abs(point.x - anchor.x), height: abs(point.y - anchor.y)
        ))
    }

    func handle(at point: CGPoint) -> SelectionHandle? {
        guard let rect else { return nil }
        let ordered = SelectionHandle.allCases.filter(\.isCorner) + SelectionHandle.allCases.filter { !$0.isCorner }
        if let handle = ordered.first(where: {
            let p = $0.point(in: rect)
            return hypot(point.x - p.x, point.y - p.y) <= Self.handleHitRadius
        }) {
            return handle
        }

        // The whole edge is draggable, not just the handle in its middle.
        let t = Self.edgeHitTolerance
        let withinX = point.x >= rect.minX - t && point.x <= rect.maxX + t
        let withinY = point.y >= rect.minY - t && point.y <= rect.maxY + t
        if withinY && abs(point.x - rect.minX) <= t { return .left }
        if withinY && abs(point.x - rect.maxX) <= t { return .right }
        if withinX && abs(point.y - rect.minY) <= t { return .top }
        if withinX && abs(point.y - rect.maxY) <= t { return .bottom }
        return nil
    }

    func moved(_ start: CGRect, by delta: CGSize) -> CGRect {
        var moved = start.offsetBy(dx: delta.width, dy: delta.height)
        moved.origin.x = min(max(moved.minX, bounds.minX), bounds.maxX - moved.width)
        moved.origin.y = min(max(moved.minY, bounds.minY), bounds.maxY - moved.height)
        return moved
    }

    func resized(_ start: CGRect, handle: SelectionHandle, by delta: CGSize) -> CGRect {
        var minX = start.minX, maxX = start.maxX, minY = start.minY, maxY = start.maxY
        switch handle {
        case .topLeft: minX += delta.width; minY += delta.height
        case .top: minY += delta.height
        case .topRight: maxX += delta.width; minY += delta.height
        case .right: maxX += delta.width
        case .bottomRight: maxX += delta.width; maxY += delta.height
        case .bottom: maxY += delta.height
        case .bottomLeft: minX += delta.width; maxY += delta.height
        case .left: minX += delta.width
        }
        // Dragging past the opposite edge flips the selection instead of collapsing it.
        return normalized(CGRect(x: min(minX, maxX), y: min(minY, maxY), width: abs(maxX - minX), height: abs(maxY - minY)))
    }

    private func normalized(_ rect: CGRect) -> CGRect {
        let clamped = rect.standardized.intersection(bounds)
        guard !clamped.isNull else { return .zero }
        let minX = clamped.minX.rounded(), minY = clamped.minY.rounded()
        let maxX = clamped.maxX.rounded(), maxY = clamped.maxY.rounded()
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// Draws the dimmed backdrop, selection border, resize handles and size badge.
final class SelectionChromeView: NSView {
    var selection: CGRect? { didSet { needsDisplay = true } }
    var showsHandles = false { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private static let dimColor = NSColor.black.withAlphaComponent(0.32)
    private static let badgeFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)

    override func draw(_ dirtyRect: NSRect) {
        Self.dimColor.setFill()
        guard let selection, selection.width > 0, selection.height > 0 else {
            NSBezierPath(rect: dirtyRect).fill()
            return
        }

        let dim = NSBezierPath(rect: bounds)
        dim.append(NSBezierPath(rect: selection))
        dim.windingRule = .evenOdd
        dim.fill()

        // Thin dark outline under a white line keeps the border visible on any background.
        NSColor.black.withAlphaComponent(0.35).setStroke()
        let outer = NSBezierPath(rect: selection.insetBy(dx: -1.5, dy: -1.5))
        outer.lineWidth = 1
        outer.stroke()
        NSColor.white.setStroke()
        let border = NSBezierPath(rect: selection.insetBy(dx: -0.5, dy: -0.5))
        border.lineWidth = 1
        border.stroke()

        if showsHandles {
            drawHandles(on: selection)
        }
        drawSizeBadge(for: selection)
    }

    private func drawHandles(on rect: CGRect) {
        let size: CGFloat = 8
        for handle in SelectionHandle.allCases {
            if !handle.isCorner && (rect.width < 40 || rect.height < 40) { continue }
            let p = handle.point(in: rect)
            let dot = NSBezierPath(ovalIn: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size))
            NSColor.white.setFill()
            dot.fill()
            NSColor.black.withAlphaComponent(0.3).setStroke()
            dot.lineWidth = 1
            dot.stroke()
        }
    }

    private func drawSizeBadge(for rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.badgeFont, .foregroundColor: NSColor.white]
        let textSize = text.size(withAttributes: attributes)
        let badgeSize = CGSize(width: ceil(textSize.width) + 12, height: ceil(textSize.height) + 6)

        var origin = CGPoint(x: rect.minX, y: rect.minY - badgeSize.height - 6)
        if origin.y < bounds.minY + 4 {
            origin.y = rect.minY + 6
            origin.x = rect.minX + 6
        }
        origin.x = min(max(origin.x, bounds.minX + 4), bounds.maxX - badgeSize.width - 4)

        let badge = CGRect(origin: origin, size: badgeSize)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 5, yRadius: 5).fill()
        text.draw(at: CGPoint(x: badge.minX + 6, y: badge.minY + 3), withAttributes: attributes)
    }
}
