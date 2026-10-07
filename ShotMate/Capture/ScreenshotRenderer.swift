import AppKit

struct RenderedScreenshot {
    /// Pixel-exact crop of the display (2× the selection on Retina) with annotations.
    let image: CGImage
    /// Size of the selection in points; recorded as PNG DPI so apps show it at its on-screen size.
    let pointSize: CGSize

    func pngData() -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = pointSize
        return rep.representation(using: .png, properties: [:])
    }
}

/// Crops the frozen display image and burns annotations in at full resolution.
enum ScreenshotRenderer {
    static func render(image: CGImage, viewSize: CGSize, selection: CGRect, annotations: [Annotation]) -> RenderedScreenshot? {
        let scaleX = CGFloat(image.width) / viewSize.width
        let scaleY = CGFloat(image.height) / viewSize.height

        let pixelRect = CGRect(
            x: selection.minX * scaleX,
            y: selection.minY * scaleY,
            width: selection.width * scaleX,
            height: selection.height * scaleY
        ).integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard !pixelRect.isEmpty, let cropped = image.cropping(to: pixelRect) else { return nil }
        let pointSize = CGSize(width: pixelRect.width / scaleX, height: pixelRect.height / scaleY)

        if annotations.isEmpty {
            return RenderedScreenshot(image: cropped, pointSize: pointSize)
        }

        let width = cropped.width
        let height = cropped.height
        let colorSpace = cropped.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        context.interpolationQuality = .none
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Map overlay coordinates (points, top-left origin) onto the cropped pixels.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scaleX, y: -scaleY)
        context.translateBy(x: -pixelRect.minX / scaleX, y: -pixelRect.minY / scaleY)
        context.setShouldAntialias(true)

        for annotation in annotations {
            annotation.draw(in: context)
        }

        guard let output = context.makeImage() else { return nil }
        return RenderedScreenshot(image: output, pointSize: pointSize)
    }
}
