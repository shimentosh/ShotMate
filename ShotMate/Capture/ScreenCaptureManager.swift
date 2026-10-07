import AppKit
import ScreenCaptureKit

/// One display's frozen contents at the moment the shortcut was pressed.
struct CapturedScreen {
    let screen: NSScreen
    /// Full backing-pixel resolution (e.g. 2× the point size on Retina).
    let image: CGImage
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case noDisplays
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "ShotMate needs Screen Recording permission to capture your screen."
        case .noDisplays:
            "ShotMate couldn't find a display to capture. If you just connected or disconnected a monitor, try again."
        case .failed:
            "ShotMate couldn't capture the screen. Please try again."
        }
    }
}

/// Captures every connected display with ScreenCaptureKit at native pixel density.
@MainActor
final class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()

    /// Display list from ScreenCaptureKit. Fetching it costs tens of milliseconds, so
    /// it is cached and refreshed only when the display configuration changes.
    private var cachedDisplays: [SCDisplay]?

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cachedDisplays = nil
                self?.warmUp()
            }
        }
    }

    /// Pre-fetches the display list so the first capture is as fast as later ones.
    func warmUp() {
        guard ScreenPermission.isGranted else { return }
        Task { _ = try? await self.displays(forceRefresh: false) }
    }

    func captureAllScreens() async throws -> [CapturedScreen] {
        do {
            return try await captureAllScreens(forceRefresh: false)
        } catch CaptureError.permissionDenied {
            throw CaptureError.permissionDenied
        } catch {
            // A cached display can go stale (sleep, reconnect); retry once with a fresh list.
            return try await captureAllScreens(forceRefresh: true)
        }
    }

    private func captureAllScreens(forceRefresh: Bool) async throws -> [CapturedScreen] {
        let displays = try await displays(forceRefresh: forceRefresh)
        let screens = NSScreen.screens.compactMap { screen -> (NSScreen, SCDisplay)? in
            guard let id = screen.displayID, let display = displays.first(where: { $0.displayID == id }) else { return nil }
            return (screen, display)
        }
        guard !screens.isEmpty else { throw CaptureError.noDisplays }

        return try await withThrowingTaskGroup(of: CapturedScreen.self) { group in
            for (screen, display) in screens {
                let pointSize = screen.frame.size
                let scale = screen.backingScaleFactor
                group.addTask {
                    let filter = SCContentFilter(display: display, excludingWindows: [])
                    let configuration = SCStreamConfiguration()
                    configuration.width = Int((pointSize.width * scale).rounded())
                    configuration.height = Int((pointSize.height * scale).rounded())
                    configuration.captureResolution = .best
                    configuration.showsCursor = false
                    configuration.scalesToFit = false
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                    return CapturedScreen(screen: screen, image: image)
                }
            }
            var results: [CapturedScreen] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }

    private func displays(forceRefresh: Bool) async throws -> [SCDisplay] {
        if !forceRefresh, let cachedDisplays {
            return cachedDisplays
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            cachedDisplays = content.displays
            return content.displays
        } catch {
            if !ScreenPermission.isGranted {
                throw CaptureError.permissionDenied
            }
            throw CaptureError.failed(error)
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
