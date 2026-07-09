import SwiftUI

/// Per-server settings sheet, reachable from a row's gear / context menu. Edits
/// the core connection fields (name, address, port, protocol, security, SNI) of
/// a single `ProxyConfig` in place while preserving all its other transport and
/// auth details. Reachable for both manual and subscription servers.
struct EditServerSheet: View {
    @Environment(ServerStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(Loc.self) private var loc

    /// The server being edited; the sheet works on a mutable copy and commits
    /// on Save so a Cancel leaves the store untouched.
    let original: ProxyConfig

    @State private var name: String
    @State private var address: String
    @State private var portText: String
    @State private var proto: ProxyProtocol
    @State private var security: StreamSecurity
    @State private var sni: String

    init(server: ProxyConfig) {
        self.original = server
        _name = State(initialValue: server.name)
        _address = State(initialValue: server.address)
        _portText = State(initialValue: String(server.port))
        _proto = State(initialValue: server.proto)
        _security = State(initialValue: server.security)
        _sni = State(initialValue: server.sni ?? "")
    }

    var body: some View {
        VStack(spacing: 18) {
            header
            fields
            footer
        }
        .padding(20)
        .frame(width: 380)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            iconTile
            Text(loc("Edit Server"))
                .font(.system(size: 17, weight: .bold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.quaternary.opacity(0.7))
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 46, height: 46)
    }

    /// "Frankfurt · VLESS / Reality" — name (flag stripped) plus protocol and,
    /// when present, the security layer.
    private var subtitle: String {
        var parts: [String] = []
        let rest = ServerFlag.split(name).rest
        if !rest.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(rest) }
        var tail = proto.displayName
        if let sec = security.displayName { tail += " / \(sec)" }
        parts.append(tail)
        return parts.joined(separator: " · ")
    }

    // MARK: - Fields

    private var fields: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeled("Name") {
                TextField("", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(alignment: .bottom, spacing: 12) {
                labeled("Address") {
                    TextField("", text: $address)
                        .textFieldStyle(.roundedBorder)
                }
                labeled("Port") {
                    TextField("", text: $portText)
                        .textFieldStyle(.roundedBorder)
                        .monospacedDigit()
                }
                .frame(width: 88)
            }

            HStack(alignment: .bottom, spacing: 12) {
                labeled("Protocol") {
                    Picker("", selection: $proto) {
                        ForEach(ProxyProtocol.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .labelsHidden()
                }
                labeled("Security") {
                    Picker("", selection: $security) {
                        ForEach(StreamSecurity.allCases, id: \.self) { s in
                            Text(loc(s.pickerLabel)).tag(s)
                        }
                    }
                    .labelsHidden()
                }
            }

            labeled("SNI") {
                TextField("", text: $sni)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func labeled<Content: View>(
        _ title: String, @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc(title))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button(loc("Cancel")) { dismiss() }
                .glassButton()
            Button(loc("Save")) { commit() }
                .glassProminentButton()
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
        }
    }

    // MARK: - Commit

    /// A name and address are required; the port must be a valid TCP/UDP port.
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !address.trimmingCharacters(in: .whitespaces).isEmpty
            && (1...65535).contains(Int(portText) ?? -1)
    }

    private func commit() {
        guard isValid, let port = Int(portText) else { return }
        var updated = original
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.address = address.trimmingCharacters(in: .whitespaces)
        updated.port = port
        updated.proto = proto
        updated.security = security
        let trimmedSNI = sni.trimmingCharacters(in: .whitespaces)
        updated.sni = trimmedSNI.isEmpty ? nil : trimmedSNI
        store.updateServer(updated)
        dismiss()
    }
}

extension StreamSecurity {
    /// Label for the Security picker; unlike `displayName`, `.none` is spelled
    /// out rather than hidden.
    var pickerLabel: String {
        switch self {
        case .none:    return "None"
        case .tls:     return "TLS"
        case .reality: return "Reality"
        }
    }
}
