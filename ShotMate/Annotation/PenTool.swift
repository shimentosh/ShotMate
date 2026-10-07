import AppKit

/// Freehand stroke, smoothed with quadratic curves through segment midpoints.
struct PenAnnotation: Annotation {
    private(set) var points: [CGPoint]
    let style: AnnotationStyle

    init(start: CGPoint, style: AnnotationStyle) {
        points = [start]
        self.style = style
    }

    var isEmpty: Bool { points.isEmpty }

    mutating func add(_ point: CGPoint) {
        guard let last = points.last, hypot(point.x - last.x, point.y - last.y) >= 0.75 else { return }
        points.append(point)
    }

    func draw(in context: CGContext) {
        guard let first = points.first else { return }
        context.saveGState()
        defer { context.restoreGState() }

        context.setStrokeColor(style.color.cgColor)
        context.setFillColor(style.color.cgColor)
        context.setLineWidth(style.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if points.count == 1 {
            let d = style.lineWidth
            context.fillEllipse(in: CGRect(x: first.x - d / 2, y: first.y - d / 2, width: d, height: d))
            return
        }

        context.move(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            context.addQuadCurve(to: mid, control: previous)
        }
        context.addLine(to: points[points.count - 1])
        context.strokePath()
    }
}
