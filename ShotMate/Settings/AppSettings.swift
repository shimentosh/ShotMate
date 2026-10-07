import AppKit
import Combine

enum AfterCaptureAction: String, CaseIterable, Identifiable {
    case copy
    case save
    case copyAndSave

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copy: "Copy to Clipboard"
        case .save: "Save to File"
        case .copyAndSave: "Copy + Save"
        }
    }

    var buttonTitle: String {
        switch self {
        case .copy: "Copy"
        case .save: "Save"
        case .copyAndSave: "Copy & Save"
        }
    }

    var buttonSymbol: String {
        switch self {
        case .copy, .copyAndSave: "doc.on.doc"
        case .save: "square.and.arrow.down"
        }
    }
}

/// The handful of user preferences ShotMate keeps, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let shortcut = "shortcut"
        static let afterCapture = "afterCaptureAction"
        static let lastSaveDirectory = "lastSaveDirectory"
        static let annotationColor = "annotationColor"
        static let lineWeight = "annotationLineWeight"
    }

    @Published var shortcut: KeyCombo {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) {
                defaults.set(data, forKey: Key.shortcut)
            }
        }
    }

    @Published var afterCapture: AfterCaptureAction {
        didSet { defaults.set(afterCapture.rawValue, forKey: Key.afterCapture) }
    }

    var lastSaveDirectory: URL? {
        get { defaults.url(forKey: Key.lastSaveDirectory) }
        set { defaults.set(newValue, forKey: Key.lastSaveDirectory) }
    }

    var annotationColor: AnnotationColor {
        get { defaults.string(forKey: Key.annotationColor).flatMap(AnnotationColor.init) ?? .red }
        set { defaults.set(newValue.rawValue, forKey: Key.annotationColor) }
    }

    var lineWeight: LineWeight {
        get { LineWeight(rawValue: defaults.integer(forKey: Key.lineWeight)) ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: Key.lineWeight) }
    }

    private init() {
        if let data = defaults.data(forKey: Key.shortcut),
           let saved = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            shortcut = saved
        } else {
            shortcut = .default
        }
        afterCapture = defaults.string(forKey: Key.afterCapture).flatMap(AfterCaptureAction.init) ?? .copy
        if defaults.object(forKey: Key.lineWeight) == nil {
            defaults.set(LineWeight.medium.rawValue, forKey: Key.lineWeight)
        }
    }
}
