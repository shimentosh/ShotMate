import AppKit
import UniformTypeIdentifiers

enum SaveError: LocalizedError {
    case encodingFailed
    case writeFailed(URL)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "ShotMate couldn't prepare the image. Please try again."
        case .writeFailed(let url):
            "ShotMate couldn't save to “\(url.deletingLastPathComponent().lastPathComponent)”. Check that the folder exists and you can write to it."
        }
    }
}

/// Writes screenshots as PNG files, remembering the last folder used.
enum ImageSaver {
    enum PanelResult {
        case saved(URL)
        case cancelled
        case failed(Error)
    }

    private static var settings: AppSettings { .shared }

    static var defaultDirectory: URL {
        settings.lastSaveDirectory
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    static func defaultFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "ShotMate \(formatter.string(from: date)).png"
    }

    /// Saves without asking, using the last folder (Desktop by default).
    static func saveToDefaultLocation(_ screenshot: RenderedScreenshot) throws -> URL {
        let url = uniqueURL(in: defaultDirectory, name: defaultFileName())
        try write(screenshot, to: url)
        return url
    }

    /// Native save dialog. Runs modally; the capture overlay must be hidden first.
    static func saveWithPanel(_ screenshot: RenderedScreenshot) -> PanelResult {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.directoryURL = defaultDirectory
        panel.nameFieldStringValue = defaultFileName()
        panel.level = .modalPanel

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return .cancelled }

        do {
            try write(screenshot, to: url)
            settings.lastSaveDirectory = url.deletingLastPathComponent()
            return .saved(url)
        } catch {
            return .failed(error)
        }
    }

    private static func write(_ screenshot: RenderedScreenshot, to url: URL) throws {
        guard let data = screenshot.pngData() else { throw SaveError.encodingFailed }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw SaveError.writeFailed(url)
        }
    }

    private static func uniqueURL(in directory: URL, name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        var candidate = directory.appendingPathComponent(name)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) (\(index)).png")
            index += 1
        }
        return candidate
    }
}
