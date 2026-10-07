import AppKit
import Combine

/// A mark drawn on top of the screenshot.
///
/// Annotations live in the overlay's coordinate space (points, top-left origin), so the
/// same `draw(in:)` renders both the live preview and the full-resolution export.
protocol Annotation {
    func draw(in context: CGContext)
    /// Annotations that are too small to be intentional (a stray click) are discarded.
    var isEmpty: Bool { get }
}

struct AnnotationStyle {
    var color: NSColor
    var lineWidth: CGFloat
    var fontSize: CGFloat
}

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pen, arrow, rectangle, text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen: "Pen"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .text: "Text"
        }
    }

    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .text: "textformat"
        }
    }

    /// Single-key shortcut inside capture mode.
    var key: String {
        switch self {
        case .pen: "p"
        case .arrow: "a"
        case .rectangle: "r"
        case .text: "t"
        }
    }
}

enum AnnotationColor: String, CaseIterable, Identifiable {
    case red, yellow, green, blue, black, white

    var id: String { rawValue }

    var nsColor: NSColor {
        switch self {
        case .red: NSColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1)
        case .yellow: NSColor(srgbRed: 1.00, green: 0.80, blue: 0.00, alpha: 1)
        case .green: NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1)
        case .blue: NSColor(srgbRed: 0.04, green: 0.52, blue: 1.00, alpha: 1)
        case .black: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        case .white: NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1)
        }
    }
}

enum LineWeight: Int, CaseIterable {
    case thin, medium, thick

    var lineWidth: CGFloat {
        switch self {
        case .thin: 2
        case .medium: 4
        case .thick: 7
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .thin: 16
        case .medium: 22
        case .thick: 30
        }
    }

    var title: String {
        switch self {
        case .thin: "Thin"
        case .medium: "Medium"
        case .thick: "Thick"
        }
    }

    var next: LineWeight { LineWeight(rawValue: rawValue + 1) ?? .thin }
}

/// Toolbar state shared by every screen's overlay during one capture.
final class AnnotationToolState: ObservableObject {
    @Published var tool: AnnotationTool?
    @Published var color: AnnotationColor {
        didSet { AppSettings.shared.annotationColor = color }
    }
    @Published var weight: LineWeight {
        didSet { AppSettings.shared.lineWeight = weight }
    }
    @Published var canUndo = false

    init() {
        color = AppSettings.shared.annotationColor
        weight = AppSettings.shared.lineWeight
    }

    var style: AnnotationStyle {
        AnnotationStyle(color: color.nsColor, lineWidth: weight.lineWidth, fontSize: weight.fontSize)
    }
}
