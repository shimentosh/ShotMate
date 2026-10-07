import AppKit

/// A single line of text placed on the screenshot.
struct TextAnnotation: Annotation {
    let text: String
    /// Top-left corner of the text's line box.
    let origin: CGPoint
    let style: AnnotationStyle

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    static func font(for style: AnnotationStyle) -> NSFont {
        .systemFont(ofSize: style.fontSize, weight: .semibold)
    }

    func draw(in context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.font(for: style),
            .foregroundColor: style.color
        ]
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        NSAttributedString(string: text, attributes: attributes).draw(at: origin)
    }
}

/// The inline editor shown while typing a text annotation. It draws in the annotation's
/// font and color so what you type is exactly what gets rendered.
final class AnnotationTextField: NSTextField {
    /// Horizontal inset AppKit applies to text inside a borderless text field.
    static let textInset: CGFloat = 2

    let style: AnnotationStyle

    init(style: AnnotationStyle) {
        self.style = style
        super.init(frame: .zero)
        isBordered = false
        isBezeled = false
        drawsBackground = false
        focusRingType = .none
        font = TextAnnotation.font(for: style)
        textColor = style.color
        lineBreakMode = .byClipping
        usesSingleLineMode = true
        cell?.wraps = false
        cell?.isScrollable = true
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.7).cgColor
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Grows the field as the user types.
    func fitToText(minimumWidth: CGFloat = 40) {
        let text = stringValue.isEmpty ? " " : stringValue
        let width = (text as NSString).size(withAttributes: [.font: font as Any]).width
        var frame = self.frame
        frame.size.width = max(minimumWidth, ceil(width) + Self.textInset * 2 + 12)
        self.frame = frame
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became, let editor = currentEditor() as? NSTextView {
            editor.insertionPointColor = style.color
        }
        return became
    }
}
