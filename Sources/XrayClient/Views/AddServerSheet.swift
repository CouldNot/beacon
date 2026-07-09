import SwiftUI
import UniformTypeIdentifiers

/// Sheet for adding one or more servers by pasting share links (into Manual group).
struct AddServerSheet: View {
    @Environment(ServerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(Loc.self) private var loc

    @State private var linkText = ""
    @State private var errorMessage: String?
    @State private var showScanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Server(s)").font(.title2).bold()
            Text(loc("Paste one or more server links, one per line, or import from a QR code. Supports VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, AnyTLS, and WireGuard."))
                .foregroundStyle(.secondary)

            TextEditor(text: $linkText)
                .font(.system(.body, design: .monospaced))
                .padding(6)
                .frame(minHeight: 120)
                .border(.secondary.opacity(0.3))

            HStack(spacing: 8) {
                Button(loc("From Image…")) {
                    importFromImage()
                }
                Button(loc("Scan Camera…")) {
                    showScanner = true
                }
                Spacer()
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") { addServers() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding().frame(width: 480)
        .sheet(isPresented: $showScanner) {
            ScannerSheet { scanned in
                appendScanned(scanned)
                showScanner = false
            }
        }
    }

    /// Opens an image file and decodes a QR-code link from it.
    private func importFromImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let payload = QRCode.decode(fileURL: url) else {
            errorMessage = "No QR code found in that image."
            return
        }
        appendScanned(payload)
    }

    /// Appends a scanned/decoded payload to the text box (newline-separated).
    private func appendScanned(_ payload: String) {
        errorMessage = nil
        if linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            linkText = payload
        } else {
            linkText += "\n" + payload
        }
    }

    private func addServers() {
        let parsed = LinkParser.parseMany(linkText)
        guard !parsed.isEmpty else {
            errorMessage = "No valid links found. Check the format."
            return
        }
        store.addManualServers(parsed)
        dismiss()
    }
}

/// A small sheet wrapping the live camera scanner.
struct ScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onScan: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Point the camera at a QR code").font(.headline)
            CameraScannerView { value in onScan(value) }
                .frame(width: 360, height: 270)
                .cornerRadius(10)
            Button("Cancel") { dismiss() }
        }
        .padding(16)
        .frame(width: 400)
    }
}

/// Sheet for importing a subscription URL as a new profile.
struct SubscriptionSheet: View {
    @Environment(ServerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var nameText = ""
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Subscription").font(.title2).bold()
            Text("Each subscription becomes its own profile group.")
                .foregroundStyle(.secondary)

            TextField("Name (optional)", text: $nameText)
                .textFieldStyle(.roundedBorder)
            TextField("https://example.com/sub", text: $urlText)
                .textFieldStyle(.roundedBorder)

            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                if isLoading { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Fetch") { Task { await fetch() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(urlText.isEmpty || isLoading)
            }
        }
        .padding().frame(width: 480)
    }

    private func fetch() async {
        isLoading = true
        message = "Fetching…"
        defer { isLoading = false }
        do {
            let result = try await SubscriptionFetcher.fetch(
                urlText, hwid: store.settings.sendHwid ? DeviceID.hwid : nil)
            guard !result.servers.isEmpty else {
                message = "Subscription returned no valid servers."
                return
            }
            let name = nameText.isEmpty
                ? (result.profileTitle ?? defaultName(from: urlText))
                : nameText
            store.addOrUpdateSubscription(name: name, url: urlText,
                                          servers: result.servers,
                                          userinfo: result.userinfo,
                                          announce: result.announce)
            dismiss()
        } catch {
            message = "Error: \(error.localizedDescription)"
        }
    }

    private func defaultName(from url: String) -> String {
        URL(string: url)?.host ?? "Subscription"
    }
}
