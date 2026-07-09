import SwiftUI
import AppKit

/// Graphical menu-bar popover: a status tile with a native connect toggle, a
/// small detail readout, and Open / Quit actions. Shown via `MenuBarExtra` in
/// `.window` style so it can render a real view instead of a plain text menu.
struct MenuBarContent: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc
    @Environment(\.openWindow) private var openWindow

    /// The server the popover describes: the active one while connected, the
    /// last selection otherwise (also what "Connect" acts on).
    private var shownServer: ProxyConfig? {
        if connection.isConnected, let active = store.server(withID: connection.activeServerID) {
            return active
        }
        return store.server(withID: store.selectedServerID)
    }

    /// Server name with any embedded/inferred flag stripped.
    private func plainName(_ server: ProxyConfig) -> String {
        ServerFlag.split(server.name).rest
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            detail
            Divider()
            actions
        }
        .frame(width: 288)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            iconTile
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                subtitle
            }
            Spacer(minLength: 8)
            Toggle("", isOn: connectBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.green)
                .disabled(shownServer == nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(accentColor.opacity(connection.isConnected ? 0.16 : 0.10))
            if connection.state == .connecting {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
        }
        .frame(width: 38, height: 38)
    }

    private var titleText: String {
        switch connection.state {
        case .connected:
            return shownServer.map(plainName) ?? loc("Connected")
        case .connecting:
            return loc("Connecting…")
        case .failed:
            return loc("Failed")
        case .disconnected:
            return loc("Not connected")
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        HStack(spacing: 5) {
            if connection.isConnected {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text(loc("Connected"))
                    .foregroundStyle(.green)
                if let server = shownServer, let ms = pinger.latency(for: server.id) ?? nil {
                    Text("· \(ms) ms")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else if connection.state == .connecting {
                if let server = shownServer {
                    Text(plainName(server)).foregroundStyle(.secondary)
                }
            } else if let server = shownServer {
                Text(plainName(server) + " · " + loc("ready"))
                    .foregroundStyle(.secondary)
            } else {
                Text(loc("No server selected")).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12))
        .lineLimit(1)
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        VStack(spacing: 7) {
            switch connection.state {
            case .connected:
                if !connection.uptimeText.isEmpty {
                    detailRow(loc("Uptime"), connection.uptimeText, mono: true)
                }
                if let server = shownServer {
                    detailRow(loc("Protocol"), protocolText(server))
                }
            case .connecting:
                detailRow(loc("Establishing tunnel"), shownServer.map(protocolText) ?? "")
            case .failed(let message):
                detailRow(loc("Failed"), message)
            case .disconnected:
                if let server = shownServer {
                    detailRow(loc("Last used"), plainName(server))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func detailRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .modifier(MonoIf(mono))
        }
        .font(.system(size: 12))
    }

    private func protocolText(_ server: ProxyConfig) -> String {
        var text = server.proto.displayName
        if let sec = server.security.displayName {
            text += " / \(sec)"
        }
        return text
    }

    // MARK: Actions

    private var actions: some View {
        HStack(spacing: 6) {
            MenuActionButton(title: loc("Open Beacon"), systemImage: "macwindow") {
                openMainWindow()
            }
            .keyboardShortcut("o")
            Spacer(minLength: 8)
            if connection.state == .connecting || connection.isConnected {
                MenuActionButton(title: connection.state == .connecting ? loc("Cancel") : loc("Quit")) {
                    connection.state == .connecting ? connection.disconnect() : quit()
                }
                .keyboardShortcut("q")
            } else {
                MenuActionButton(title: loc("Quit")) { quit() }
                    .keyboardShortcut("q")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: Actions plumbing

    private var connectBinding: Binding<Bool> {
        Binding(
            get: { connection.isConnected || connection.state == .connecting },
            set: { on in
                if on {
                    if let server = shownServer { connection.connect(to: server) }
                } else {
                    connection.disconnect()
                }
            }
        )
    }

    private var accentColor: Color {
        switch connection.state {
        case .connected:  return .green
        case .connecting: return .orange
        case .failed:     return .red
        case .disconnected: return .secondary
        }
    }

    private func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Focus an already-open main window instead of spawning another
        // instance; only ask SwiftUI for a new one when none exists (e.g. after
        // the window was closed to the tray). The menu-bar popover panel can't
        // become main, so `canBecomeMain` cleanly excludes it.
        if let existing = NSApp.windows.first(where: { $0.canBecomeMain }) {
            existing.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }

    private func quit() {
        connection.disconnect()
        NSApp.terminate(nil)
    }
}

/// A borderless menu-style action button with a hover highlight, matching the
/// look of native menu rows inside the popover.
private struct MenuActionButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text(title).font(.system(size: 13))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.08 : 0))
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { hovering = $0 }
    }
}

/// Applies monospaced digits only when requested, so a single `detailRow`
/// helper can style both text and numeric values.
private struct MonoIf: ViewModifier {
    let enabled: Bool
    init(_ enabled: Bool) { self.enabled = enabled }
    func body(content: Content) -> some View {
        enabled ? AnyView(content.monospacedDigit()) : AnyView(content)
    }
}
