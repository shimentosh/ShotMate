import SwiftUI

/// The small floating bar shown next to the selection.
struct CaptureToolbar: View {
    @ObservedObject var state: AnnotationToolState
    let primaryAction: AfterCaptureAction
    let onUndo: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void
    let onPrimary: () -> Void
    let onInteraction: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AnnotationTool.allCases) { tool in
                ToolbarIconButton(
                    symbol: tool.symbol,
                    help: "\(tool.title) (\(tool.key.uppercased()))",
                    isSelected: state.tool == tool
                ) {
                    state.tool = state.tool == tool ? nil : tool
                    onInteraction()
                }
            }

            ToolbarDivider()

            HStack(spacing: 5) {
                ForEach(AnnotationColor.allCases) { color in
                    ColorSwatch(color: color, isSelected: state.color == color) {
                        state.color = color
                        onInteraction()
                    }
                }
            }
            .padding(.horizontal, 5)

            WeightButton(weight: state.weight, color: Color(nsColor: state.color.nsColor)) {
                state.weight = state.weight.next
                onInteraction()
            }

            ToolbarDivider()

            ToolbarIconButton(symbol: "arrow.uturn.backward", help: "Undo (⌘Z)", isEnabled: state.canUndo, action: onUndo)
            ToolbarIconButton(symbol: "xmark", help: "Cancel (Esc)", action: onCancel)
            ToolbarIconButton(symbol: "square.and.arrow.down", help: "Save As… (⌘S)", action: onSave)

            Button(action: onPrimary) {
                HStack(spacing: 5) {
                    Image(systemName: primaryAction.buttonSymbol)
                        .font(.system(size: 11, weight: .semibold))
                    Text(primaryAction.buttonTitle)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.accentColor))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(primaryAction.buttonTitle) (↩)")
            .padding(.leading, 4)
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .fixedSize()
    }
}

private struct ToolbarIconButton: View {
    let symbol: String
    let help: String
    var isSelected = false
    var isEnabled = true
    let action: () -> Void

    @StateObject private var hover = HoverState()

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(hover.isHovering ? 0.1 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .onHover { hover.isHovering = $0 }
        .help(help)
    }
}

private struct ColorSwatch: View {
    let color: AnnotationColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(nsColor: color.nsColor))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5))
                .frame(width: 14, height: 14)
                .padding(2)
                .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(color.rawValue.capitalized)
    }
}

private struct WeightButton: View {
    let weight: LineWeight
    let color: Color
    let action: () -> Void

    @StateObject private var hover = HoverState()

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(color)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5))
                .frame(width: 16, height: weight.lineWidth + 1)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(hover.isHovering ? 0.1 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.isHovering = $0 }
        .help("Thickness: \(weight.title)")
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 4)
    }
}
