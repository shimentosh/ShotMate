import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

/// Borderless full-screen window covering one display during a capture.
final class CaptureOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// What the user asked to do with the finished screenshot.
enum CaptureOutput {
    /// The "After capture" default from settings (Enter / primary button).
    case primary
    case copy
    case saveAs
}

/// Shows one display's frozen image and handles selection, annotation and keyboard input.
final class CaptureOverlayView: NSView, NSTextFieldDelegate {
    weak var coordinator: CaptureCoordinator?
    let screenImage: CGImage

    private let toolState: AnnotationToolState
    private var selection: SelectionManager
    private let imageView = NSImageView()
    private let canvas = AnnotationCanvas()
    private let chrome = SelectionChromeView()
    private var toolbarHost: NSHostingView<CaptureToolbar>?
    private var textField: AnnotationTextField?
    private var trackingArea: NSTrackingArea?
    private var cancellables = Set<AnyCancellable>()

    private enum DragMode {
        case none
        case creating(anchor: CGPoint)
        case moving(start: CGRect, mouse: CGPoint)
        case resizing(SelectionHandle, start: CGRect, mouse: CGPoint)
        case annotating
    }

    private var dragMode = DragMode.none

    var hasSelection: Bool { selection.rect != nil }
    var hasAnnotations: Bool { canvas.hasAnnotations }

    init(frame: CGRect, image: CGImage, toolState: AnnotationToolState) {
        screenImage = image
        self.toolState = toolState
        selection = SelectionManager(bounds: CGRect(origin: .zero, size: frame.size))
        super.init(frame: frame)
        wantsLayer = true

        imageView.image = NSImage(cgImage: image, size: frame.size)
        imageView.imageScaling = .scaleAxesIndependently
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)

        canvas.frame = bounds
        canvas.autoresizingMask = [.width, .height]
        addSubview(canvas)

        chrome.frame = bounds
        chrome.autoresizingMask = [.width, .height]
        addSubview(chrome)

        toolState.$tool
            .dropFirst()
            .sink { [weak self] _ in
                self?.commitTextEditing()
                self?.updateCursor()
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Hit testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if let textField, textField.frame.contains(local) {
            return textField.hitTest(local) ?? textField
        }
        if let toolbarHost, !toolbarHost.isHidden, toolbarHost.frame.contains(local) {
            return toolbarHost.hitTest(local)
        }
        return bounds.contains(local) ? self : nil
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        let point = location(of: event)

        if textField != nil {
            commitTextEditing()
            return
        }
        window?.makeFirstResponder(self)

        if let rect = selection.rect {
            if let handle = selection.handle(at: point) {
                dragMode = .resizing(handle, start: rect, mouse: point)
                setToolbarVisible(false)
                return
            }
            if let tool = toolState.tool, rect.contains(point) {
                if tool == .text {
                    beginTextEditing(at: point)
                } else {
                    canvas.begin(tool, at: point, style: toolState.style)
                    dragMode = .annotating
                }
                return
            }
            if toolState.tool == nil, rect.contains(point) {
                if event.clickCount == 2 {
                    coordinator?.finish(.primary, from: self)
                    return
                }
                dragMode = .moving(start: rect, mouse: point)
                NSCursor.closedHand.set()
                setToolbarVisible(false)
                return
            }
            // Starting a new selection would throw away the marks already made.
            if canvas.hasAnnotations { return }
        }

        guard coordinator?.overlayWillBeginSelection(self) ?? true else { return }
        selection.clear()
        dragMode = .creating(anchor: point)
        setToolbarVisible(false)
        refreshChrome()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = location(of: event)
        switch dragMode {
        case .creating(let anchor):
            selection.set(selection.rect(from: anchor, to: clamped(point)))
        case .moving(let start, let mouse):
            selection.set(selection.moved(start, by: CGSize(width: point.x - mouse.x, height: point.y - mouse.y)))
        case .resizing(let handle, let start, let mouse):
            selection.set(selection.resized(start, handle: handle, by: CGSize(width: point.x - mouse.x, height: point.y - mouse.y)))
        case .annotating:
            canvas.update(to: point)
            return
        case .none:
            return
        }
        refreshChrome()
    }

    override func mouseUp(with event: NSEvent) {
        switch dragMode {
        case .creating:
            // A click without a drag selects the whole display.
            if let rect = selection.rect, rect.width >= SelectionManager.minimumSize, rect.height >= SelectionManager.minimumSize {
                break
            }
            selection.set(bounds)
        case .annotating:
            canvas.end()
            toolState.canUndo = canvas.hasAnnotations
        case .moving, .resizing, .none:
            break
        }
        dragMode = .none
        refreshChrome()
        layoutToolbar()
        updateCursor()
    }

    override func rightMouseDown(with event: NSEvent) {
        coordinator?.cancel()
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        switch Int(event.keyCode) {
        case kVK_Escape:
            coordinator?.cancel()
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if hasSelection { coordinator?.finish(.primary, from: self) }
        case kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow:
            nudgeSelection(keyCode: Int(event.keyCode), by: modifiers.contains(.shift) ? 10 : 1)
        default:
            guard modifiers.isEmpty, hasSelection,
                  let key = event.charactersIgnoringModifiers?.lowercased(),
                  let tool = AnnotationTool.allCases.first(where: { $0.key == key }) else { return }
            toolState.tool = toolState.tool == tool ? nil : tool
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // While typing a text annotation, ⌘ shortcuts belong to the text field.
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers == [.command] else { return super.performKeyEquivalent(with: event) }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "z":
            undo()
        case "c":
            if hasSelection { coordinator?.finish(.copy, from: self) }
        case "s":
            if hasSelection { coordinator?.finish(.saveAs, from: self) }
        case "w":
            coordinator?.cancel()
        default:
            return super.performKeyEquivalent(with: event)
        }
        return true
    }

    func undo() {
        if textField != nil {
            cancelTextEditing()
            return
        }
        canvas.undo()
        toolState.canUndo = canvas.hasAnnotations
    }

    private func nudgeSelection(keyCode: Int, by step: CGFloat) {
        guard let rect = selection.rect else { return }
        let delta: CGSize = switch keyCode {
        case kVK_LeftArrow: CGSize(width: -step, height: 0)
        case kVK_RightArrow: CGSize(width: step, height: 0)
        case kVK_UpArrow: CGSize(width: 0, height: -step)
        default: CGSize(width: 0, height: step)
        }
        selection.set(selection.moved(rect, by: delta))
        refreshChrome()
        layoutToolbar()
    }

    // MARK: - Selection state

    /// Called by the coordinator when the user starts selecting on another display.
    func clearSelection() {
        commitTextEditing()
        selection.clear()
        dragMode = .none
        setToolbarVisible(false)
        refreshChrome()
    }

    private func refreshChrome() {
        chrome.selection = selection.rect
        if case .creating = dragMode {
            chrome.showsHandles = false
        } else {
            chrome.showsHandles = selection.rect != nil
        }
        canvas.clipRect = selection.rect
    }

    // MARK: - Toolbar

    private func makeToolbar() -> NSHostingView<CaptureToolbar> {
        let toolbar = CaptureToolbar(
            state: toolState,
            primaryAction: AppSettings.shared.afterCapture,
            onUndo: { [weak self] in self?.undo(); self?.restoreFocus() },
            onCancel: { [weak self] in self?.coordinator?.cancel() },
            onSave: { [weak self] in
                guard let self else { return }
                self.coordinator?.finish(.saveAs, from: self)
            },
            onPrimary: { [weak self] in
                guard let self else { return }
                self.coordinator?.finish(.primary, from: self)
            },
            onInteraction: { [weak self] in self?.restoreFocus() }
        )
        let host = NSHostingView(rootView: toolbar)
        host.isHidden = true
        addSubview(host)
        toolbarHost = host
        return host
    }

    private func setToolbarVisible(_ visible: Bool) {
        if visible {
            layoutToolbar()
        } else {
            toolbarHost?.isHidden = true
        }
    }

    private func layoutToolbar() {
        guard let rect = selection.rect else {
            toolbarHost?.isHidden = true
            return
        }
        let host = toolbarHost ?? makeToolbar()
        let size = host.fittingSize
        let margin: CGFloat = 8

        let y: CGFloat
        if rect.maxY + margin + size.height <= bounds.maxY - margin {
            y = rect.maxY + margin
        } else if rect.minY - margin - size.height >= bounds.minY + margin {
            y = rect.minY - margin - size.height
        } else {
            y = rect.maxY - margin - size.height
        }
        let x = min(max(rect.maxX - size.width, bounds.minX + margin), bounds.maxX - size.width - margin)

        host.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
        host.isHidden = false
    }

    private func restoreFocus() {
        if textField == nil {
            window?.makeFirstResponder(self)
        }
    }

    // MARK: - Text annotations

    private func beginTextEditing(at point: CGPoint) {
        let field = AnnotationTextField(style: toolState.style)
        field.delegate = self
        let height = ceil(field.fittingSize.height)
        field.frame = CGRect(x: point.x - AnnotationTextField.textInset, y: point.y - height / 2, width: 40, height: height)
        field.fitToText()
        addSubview(field, positioned: .below, relativeTo: toolbarHost)
        textField = field
        window?.makeFirstResponder(field)
        updateCursor()
    }

    func commitTextEditing() {
        guard let field = textField else { return }
        textField = nil
        let annotation = TextAnnotation(
            text: field.stringValue,
            origin: CGPoint(x: field.frame.minX + AnnotationTextField.textInset, y: field.frame.minY),
            style: field.style
        )
        window?.makeFirstResponder(self)
        field.removeFromSuperview()
        canvas.add(annotation)
        toolState.canUndo = canvas.hasAnnotations
    }

    private func cancelTextEditing() {
        guard let field = textField else { return }
        textField = nil
        window?.makeFirstResponder(self)
        field.removeFromSuperview()
    }

    func controlTextDidChange(_ notification: Notification) {
        textField?.fitToText()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) || commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            commitTextEditing()
            return true
        }
        return false
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        commitTextEditing()
    }

    // MARK: - Output

    /// Renders the selection plus annotations at the display's native pixel density.
    func renderScreenshot() -> RenderedScreenshot? {
        commitTextEditing()
        guard let rect = selection.rect, rect.width >= 1, rect.height >= 1 else { return nil }
        return ScreenshotRenderer.render(image: screenImage, viewSize: bounds.size, selection: rect, annotations: canvas.annotations)
    }

    // MARK: - Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(at: location(of: event))
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(at: location(of: event))
    }

    func updateCursor() {
        guard let window else { return }
        updateCursor(at: convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    private func updateCursor(at point: CGPoint) {
        cursor(at: point).set()
    }

    private func cursor(at point: CGPoint) -> NSCursor {
        if let toolbarHost, !toolbarHost.isHidden, toolbarHost.frame.contains(point) { return .arrow }
        if let textField, textField.frame.contains(point) { return .iBeam }
        guard let rect = selection.rect else { return .crosshair }
        if let handle = selection.handle(at: point) { return handle.cursor }
        if rect.contains(point) {
            switch toolState.tool {
            case .text: return .iBeam
            case .some: return .crosshair
            case .none: return .openHand
            }
        }
        return canvas.hasAnnotations ? .arrow : .crosshair
    }

    // MARK: - Helpers

    private func location(of event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX), y: min(max(point.y, bounds.minY), bounds.maxY))
    }
}
