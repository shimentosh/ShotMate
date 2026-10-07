import SwiftUI

/// The three settings ShotMate has: shortcut, after-capture action, launch at login.
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var launchAtLogin = LaunchAtLogin.shared
    @ObservedObject var recorder: ShortcutRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ShortcutSetting(recorder: recorder, shortcut: settings.shortcut)

            HStack {
                Text("After Capture")
                Spacer()
                Picker("After Capture", selection: $settings.afterCapture) {
                    ForEach(AfterCaptureAction.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Launch at Login")
                    Spacer()
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                if launchAtLogin.needsApproval {
                    Button("Allow ShotMate in Login Items…") { launchAtLogin.openLoginItemsSettings() }
                        .buttonStyle(.link)
                        .font(.caption)
                } else if let error = launchAtLogin.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 14)
    }
}

private struct ShortcutSetting: View {
    @ObservedObject var recorder: ShortcutRecorder
    let shortcut: KeyCombo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Shortcut")
                Spacer()
                if recorder.isRecording {
                    if recorder.liveModifiers.isEmpty {
                        Text("Press shortcut…")
                            .foregroundStyle(Color.accentColor)
                    } else {
                        KeyCaps(keys: KeyCombo.modifierSymbols(recorder.liveModifiers), highlighted: true)
                    }
                } else {
                    KeyCaps(keys: shortcut.keyCaps, highlighted: false)
                }
            }

            HStack(spacing: 12) {
                Spacer()
                if shortcut != .default && !recorder.isRecording {
                    Button("Reset") { recorder.resetToDefault() }
                        .buttonStyle(.link)
                }
                Button(recorder.isRecording ? "Cancel" : "Change Shortcut") {
                    recorder.isRecording ? recorder.cancel() : recorder.start()
                }
                .buttonStyle(.link)
            }
            .font(.system(size: 12))

            if let message = recorder.message {
                Label(message.text, systemImage: message.kind == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(message.kind == .error ? Color.red : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct KeyCaps: View {
    let keys: [String]
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .frame(minWidth: 20, minHeight: 20)
                    .padding(.horizontal, key.count > 1 ? 4 : 0)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(highlighted ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            }
        }
    }
}
