import SwiftUI
import AVFoundation
import AppKit

/// A live camera QR-code scanner. Calls `onScan` with the first decoded payload.
/// Falls back gracefully (shows nothing useful) if no camera is available.
struct CameraScannerView: NSViewRepresentable {
    var onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeNSView(context: Context) -> ScannerNSView {
        let view = ScannerNSView()
        view.coordinator = context.coordinator
        view.start()
        return view
    }

    func updateNSView(_ nsView: ScannerNSView, context: Context) {}

    static func dismantleNSView(_ nsView: ScannerNSView, coordinator: Coordinator) {
        nsView.stop()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !didScan else { return }
            for obj in metadataObjects {
                if let qr = obj as? AVMetadataMachineReadableCodeObject,
                   qr.type == .qr, let value = qr.stringValue, !value.isEmpty {
                    didScan = true
                    // The delegate queue is .main, so deliver directly. Capture
                    // the handler locally to avoid sending `self` across actors.
                    let handler = onScan
                    handler(value)
                    return
                }
            }
        }
    }
}

/// Hosts the AVCaptureVideoPreviewLayer and owns the capture session.
/// Everything runs on the main actor (NSView is @MainActor): configuration for
/// a QR sheet is cheap, which keeps this clean under strict concurrency.
final class ScannerNSView: NSView {
    weak var coordinator: CameraScannerView.Coordinator?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func start() {
        // Ask for camera permission (callback is on an arbitrary queue), then
        // hop back to the main actor to configure the session.
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { return }
            Task { @MainActor [weak self] in self?.configure() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(coordinator, queue: .main)
            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
            }
        }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer?.addSublayer(preview)
        self.preview = preview

        session.startRunning()
    }

    func stop() {
        session.stopRunning()
    }

    override func layout() {
        super.layout()
        preview?.frame = bounds
    }
}
