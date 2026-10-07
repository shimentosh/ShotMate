import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var recorder: ShortcutRecorder
    @ObservedObject var permission: PermissionStatus
    let onCapture: () -> Void
    let onGrantPermission: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ShotMate")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            MenuRow(action: onCapture) {
                Image(systemName: "viewfinder")
                    .frame(width: 18)
                Text("Capture Screenshot")
                Spacer()
                Text(settings.shortcut.displayString)
                    .foregroundStyle(.secondary)
            }

            if !permission.isGranted {
                MenuRow(action: onGrantPermission) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 18)
                    Text("Allow Screen Recording…")
                    Spacer()
                }
            }

            Divider().padding(.vertical, 6).padding(.horizontal, 14)

            SettingsView(recorder: recorder)

            Divider().padding(.vertical, 6).padding(.horizontal, 14)

            MenuRow(action: onQuit) {
                Text("Quit ShotMate")
                Spacer()
                Text("⌘Q").foregroundStyle(.secondary)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .font(.system(size: 13))
        .padding(.bottom, 6)
        .frame(width: 300)
    }
}

/// A full-width, menu-style row that highlights on hover.
struct MenuRow<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: Content

    @StateObject private var hover = HoverState()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { content }
                .padding(.horizontal, 8)
                .frame(height: 26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hover.isHovering ? Color.primary.opacity(0.09) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { hover.isHovering = $0 }
    }
}
