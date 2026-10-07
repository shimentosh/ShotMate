import AppKit

/// Rectangular outline dragged from one corner to the other.
struct RectangleAnnotation: Annotation {
    let start: CGPoint
    var end: CGPoint
    let style: AnnotationStyle

    var rect: CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    var isEmpty: Bool { rect.width < 3 && rect.height < 3 }

    func draw(in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        context.setStrokeColor(style.color.cgColor)
        context.setLineWidth(style.lineWidth)
        context.setLineJoin(.round)
        let radius = min(style.lineWidth, rect.width / 2, rect.height / 2)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.strokePath()
    }
}
