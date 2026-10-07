import AppKit

/// Straight arrow with a solid head that scales with the line weight.
struct ArrowAnnotation: Annotation {
    let start: CGPoint
    var end: CGPoint
    let style: AnnotationStyle

    var isEmpty: Bool { hypot(end.x - start.x, end.y - start.y) < 4 }

    func draw(in context: CGContext) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 1 else { return }

        let ux = dx / length
        let uy = dy / length
        let headLength = min(max(style.lineWidth * 3.5 + 6, 12), length)
        let headHalfWidth = headLength * 0.55

        let base = CGPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)
        let left = CGPoint(x: base.x + uy * headHalfWidth, y: base.y - ux * headHalfWidth)
        let right = CGPoint(x: base.x - uy * headHalfWidth, y: base.y + ux * headHalfWidth)
        // End the shaft inside the head so the round cap never pokes out of the tip.
        let shaftEnd = CGPoint(x: end.x - ux * headLength * 0.6, y: end.y - uy * headLength * 0.6)

        context.saveGState()
        defer { context.restoreGState() }

        context.setStrokeColor(style.color.cgColor)
        context.setFillColor(style.color.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if length > headLength {
            context.setLineWidth(style.lineWidth)
            context.move(to: start)
            context.addLine(to: shaftEnd)
            context.strokePath()
        }

        context.setLineWidth(max(1, style.lineWidth * 0.5))
        context.move(to: end)
        context.addLine(to: left)
        context.addLine(to: right)
        context.closePath()
        context.drawPath(using: .fillStroke)
    }
}
