import AppKit

enum ClipboardError: LocalizedError {
    case encodingFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: "ShotMate couldn't prepare the image. Please try again."
        case .writeFailed: "ShotMate couldn't copy the screenshot to the clipboard. Please try again."
        }
    }
}

/// Puts the finished screenshot on the general pasteboard as an image.
enum ClipboardManager {
    /// Kept alive until the next copy so the lazily-provided TIFF can still be produced.
    private static var tiffProvider: TIFFProvider?

    static func copy(_ screenshot: RenderedScreenshot) throws {
        guard let png = screenshot.pngData() else { throw ClipboardError.encodingFailed }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // PNG is what modern apps (browsers, Electron apps, Slack, VS Code) read. TIFF is
        // only produced if an older app asks for it, so the common case stays fast.
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        let provider = TIFFProvider(screenshot: screenshot)
        item.setDataProvider(provider, forTypes: [.tiff])
        tiffProvider = provider

        guard pasteboard.writeObjects([item]) else { throw ClipboardError.writeFailed }
    }

    private final class TIFFProvider: NSObject, NSPasteboardItemDataProvider {
        private let screenshot: RenderedScreenshot

        init(screenshot: RenderedScreenshot) {
            self.screenshot = screenshot
        }

        func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
            let rep = NSBitmapImageRep(cgImage: screenshot.image)
            rep.size = screenshot.pointSize
            if let tiff = rep.tiffRepresentation(using: .lzw, factor: 0) {
                item.setData(tiff, forType: .tiff)
            }
        }
    }
}
