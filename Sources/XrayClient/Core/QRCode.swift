import Foundation
import CoreImage
import AppKit

/// QR-code generation and decoding helpers built on CoreImage.
enum QRCode {

    /// Renders `string` into a crisp QR-code NSImage of roughly `size` points.
    static func image(from string: String, size: CGFloat = 240) -> NSImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        // "H" = high error correction, robust when displayed/printed small.
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }

        // Scale the (small) generated image up to the requested point size.
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
    }

    /// Detects and returns the first QR-code payload found in an image, if any.
    static func decode(from image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let ci = CIImage(data: tiff) else { return nil }
        return decode(ciImage: ci)
    }

    /// Decodes a QR payload from raw image data (e.g. a dropped/opened file).
    static func decode(fileURL: URL) -> String? {
        guard let ci = CIImage(contentsOf: fileURL) else { return nil }
        return decode(ciImage: ci)
    }

    static func decode(ciImage: CIImage) -> String? {
        let context = CIContext()
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: context,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) ?? []
        for case let qr as CIQRCodeFeature in features {
            if let msg = qr.messageString, !msg.isEmpty { return msg }
        }
        return nil
    }
}
