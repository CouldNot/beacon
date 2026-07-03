import SwiftUI
import AppKit

/// Shows a server's share link as a QR code, with copy + save actions.
struct QRDisplaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let server: ProxyConfig

    private var link: String { LinkBuilder.link(for: server) }

    var body: some View {
        VStack(spacing: 14) {
            Text(server.name).font(.headline).lineLimit(1)

            if let img = QRCode.image(from: link, size: 240) {
                Image(nsImage: img)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 240, height: 240)
                    .background(Color.white)
                    .cornerRadius(8)
            } else {
                Text("Could not render QR code.")
                    .foregroundStyle(.secondary)
                    .frame(width: 240, height: 240)
            }

            Text(link)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: 280)

            HStack {
                Button("Copy link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(link, forType: .string)
                }
                Button("Save PNG…") { savePNG() }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: 280)
        }
        .padding(20)
        .frame(width: 320)
    }

    private func savePNG() {
        guard let img = QRCode.image(from: link, size: 512),
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(server.name).png"
        if panel.runModal() == .OK, let url = panel.url {
            try? png.write(to: url)
        }
    }
}
