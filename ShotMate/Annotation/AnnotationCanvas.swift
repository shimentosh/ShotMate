import AppKit

/// Transparent layer above the frozen screen image that holds and draws annotations.
final class AnnotationCanvas: NSView {
    private(set) var annotations: [Annotation] = []
    private var inProgress: Annotation?

    /// Annotations are only visible inside the selection, matching the exported image.
    var clipRect: CGRect? {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    var hasAnnotations: Bool { !annotations.isEmpty }

    func begin(_ tool: AnnotationTool, at point: CGPoint, style: AnnotationStyle) {
        switch tool {
        case .pen: inProgress = PenAnnotation(start: point, style: style)
        case .arrow: inProgress = ArrowAnnotation(start: point, end: point, style: style)
        case .rectangle: inProgress = RectangleAnnotation(start: point, end: point, style: style)
        case .text: inProgress = nil
        }
        needsDisplay = true
    }

    func update(to point: CGPoint) {
        switch inProgress {
        case var pen as PenAnnotation:
            pen.add(point)
            inProgress = pen
        case var arrow as ArrowAnnotation:
            arrow.end = point
            inProgress = arrow
        case var rectangle as RectangleAnnotation:
            rectangle.end = point
            inProgress = rectangle
        default:
            return
        }
        needsDisplay = true
    }

    func end() {
        if let annotation = inProgress, !annotation.isEmpty {
            annotations.append(annotation)
        }
        inProgress = nil
        needsDisplay = true
    }

    func add(_ annotation: Annotation) {
        guard !annotation.isEmpty else { return }
        annotations.append(annotation)
        needsDisplay = true
    }

    @discardableResult
    func undo() -> Bool {
        guard !annotations.isEmpty else { return false }
        annotations.removeLast()
        needsDisplay = true
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let clipRect, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.clip(to: clipRect)
        for annotation in annotations {
            annotation.draw(in: context)
        }
        inProgress?.draw(in: context)
        context.restoreGState()
    }
}
