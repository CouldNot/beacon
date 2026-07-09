import SwiftUI

/// Basic app settings: tunnel mode, appearance, auto-update, close-to-tray, ports.
/// Hosted as the Settings destination in the sidebar. (Restyled into grouped
/// glass sections in a later step.)
struct SettingsPane: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(Loc.self) private var loc

    @State private var helperInstalled = TunManager.isHelperInstalled
    @State private var showRouting = false
    @State private var refreshHoursText = ""
    @State private var showRefreshHoursPopover = false
    @State private var portFieldText = ""
    @State private var editingPortField: PortField?

    private enum PortField: Identifiable {
        case socks, http
        var id: Self { self }
        var title: String {
            switch self {
            case .socks: return "SOCKS port"
            case .http:  return "HTTP port"
            }
        }
    }

    var body: some View {
        @Bindable var store = store
        Form {
                Section(loc("Tunnel")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker(loc("Mode"), selection: $store.settings.mode) {
                            ForEach(TunnelMode.allCases) { m in Text(m.title).tag(m) }
                        }
                        .onChange(of: store.settings.mode) { _, m in
                            connection.mode = m; store.save()
                        }
                        Text(store.settings.mode.subtitle)
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(loc("SOCKS port"))
                        Spacer()
                        Text(String(store.settings.socksPort))
                            .foregroundStyle(.secondary)
                        Button(loc("Set…")) {
                            portFieldText = "\(store.settings.socksPort)"
                            editingPortField = .socks
                        }
                        .glassButton()
                    }
                    HStack {
                        Text(loc("HTTP port"))
                        Spacer()
                        Text(String(store.settings.httpPort))
                            .foregroundStyle(.secondary)
                        Button(loc("Set…")) {
                            portFieldText = "\(store.settings.httpPort)"
                            editingPortField = .http
                        }
                        .glassButton()
                    }
                    Picker(loc("Log level"), selection: $store.settings.logLevel) {
                        ForEach(LogLevel.allCases) { l in Text(l.title).tag(l) }
                    }
                    .onChange(of: store.settings.logLevel) { _, l in
                        connection.logLevel = l; store.save()
                    }
                }

                Section(loc("Routing")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.settings.routingPreset.title)
                            Text(store.settings.routingPreset.subtitle)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(loc("Configure…")) { showRouting = true }
                            .glassButton()
                    }
                }

                Section(loc("Appearance")) {
                    Picker(loc("Theme"), selection: $store.settings.appearance) {
                        ForEach(AppAppearance.allCases) { a in Text(a.title).tag(a) }
                    }
                    .onChange(of: store.settings.appearance) { _, _ in store.save() }

                    Picker(loc("Language"), selection: $store.settings.language) {
                        ForEach(AppLanguage.allCases) { l in
                            Text(l == .system ? loc("System") : l.displayName).tag(l)
                        }
                    }
                    .onChange(of: store.settings.language) { _, newLang in
                        loc.language = newLang; store.save()
                    }
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(helperInstalled ? loc("Helper installed") : loc("Helper not installed"))
                            Text(helperInstalled
                                 ? "TUN switches servers without asking for a password."
                                 : "Install once to stop password prompts on every switch.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if helperInstalled {
                            Button(loc("Remove")) {
                                TunManager.uninstallHelper()
                                helperInstalled = TunManager.isHelperInstalled
                            }
                            .glassButton().tint(.red)
                        } else {
                            Button(loc("Install")) {
                                try? TunManager.installHelper()
                                helperInstalled = TunManager.isHelperInstalled
                            }
                            .glassProminentButton()
                        }
                    }
                } header: {
                    Text("TUN Helper (no-password)")
                }

                Section(loc("Subscriptions")) {
                    Toggle(loc("Auto-update subscriptions"), isOn: $store.settings.autoUpdateSubscriptions)
                        .onChange(of: store.settings.autoUpdateSubscriptions) { _, _ in store.save() }
                    HStack {
                        Text(loc("Subscription refresh period"))
                        Spacer()
                        Text("\(String(store.settings.autoUpdateIntervalHours)) \(loc("hr"))")
                            .foregroundStyle(.secondary)
                        Button(loc("Set…")) {
                            refreshHoursText = "\(store.settings.autoUpdateIntervalHours)"
                            showRefreshHoursPopover = true
                        }
                        .glassButton()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(loc("Send HWID with subscription requests"), isOn: $store.settings.sendHwid)
                            .onChange(of: store.settings.sendHwid) { _, _ in store.save() }
                        Text(loc("Identifies this device to providers that require it."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section(loc("Window")) {
                    Toggle(loc("Close button hides to menu bar"), isOn: $store.settings.closeToTray)
                        .onChange(of: store.settings.closeToTray) { _, _ in store.save() }
                    Toggle(loc("Auto-connect on launch"), isOn: $store.settings.autoConnectOnLaunch)
                        .onChange(of: store.settings.autoConnectOnLaunch) { _, _ in store.save() }
                    Toggle(loc("Launch at login"), isOn: $store.settings.launchAtLogin)
                        .onChange(of: store.settings.launchAtLogin) { _, on in
                            LoginItem.setEnabled(on); store.save()
                        }
                    Toggle(loc("Notify on connect / disconnect"), isOn: $store.settings.notifyOnConnect)
                        .onChange(of: store.settings.notifyOnConnect) { _, on in
                            connection.notifyOnConnect = on
                            if on { NotificationManager.requestAuthorization() }
                            store.save()
                        }
                }
        }
        .formStyle(.grouped)
        // Let the shared window material show through; the opaque grouped-form
        // background would otherwise extend under the titlebar and paint over
        // the floating header pill.
        .scrollContentBackground(.hidden)
        .navigationTitle(loc("Settings"))
        .sheet(isPresented: $showRouting) { RoutingSheet() }
        .sheet(isPresented: $showRefreshHoursPopover) { refreshHoursSheet }
        .sheet(item: $editingPortField) { field in portFieldSheet(field) }
        .onChange(of: store.settings.socksPort) { _, p in
            connection.ports.socks = p; store.save()
        }
        .onChange(of: store.settings.httpPort) { _, p in
            connection.ports.http = p; store.save()
        }
    }

    /// Shared design for the "set a single value" prompt sheets (subscription
    /// refresh period, SOCKS/HTTP ports): a System-Settings-style card with a
    /// tinted content row (label left, field right) above a divider and a
    /// trailing Cancel/Done footer.
    private func promptSheet(
        label: String,
        text: Binding<String>,
        suffix: String? = nil,
        onCancel: @escaping () -> Void,
        onCommit: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                Spacer()
                TextField("", text: text)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .onSubmit(onCommit)
                if let suffix {
                    Text(suffix).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.primary.opacity(0.08)))
            .padding(16)

            Divider()

            HStack {
                Spacer()
                Button(loc("Cancel"), action: onCancel)
                    .glassButton()
                Button(loc("Done"), action: onCommit)
                    .glassProminentButton()
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 380)
    }

    private var refreshHoursSheet: some View {
        promptSheet(
            label: loc("Refresh every:"),
            text: $refreshHoursText,
            suffix: loc("hr"),
            onCancel: { showRefreshHoursPopover = false },
            onCommit: commitRefreshHours
        )
    }

    private func commitRefreshHours() {
        if let hours = Int(refreshHoursText.trimmingCharacters(in: .whitespaces)) {
            store.settings.autoUpdateIntervalHours = min(max(hours, 1), 168)
            store.save()
        }
        showRefreshHoursPopover = false
    }

    private func portFieldSheet(_ field: PortField) -> some View {
        promptSheet(
            label: loc(field.title) + ":",
            text: $portFieldText,
            onCancel: { editingPortField = nil },
            onCommit: { commitPortField(field) }
        )
    }

    private func commitPortField(_ field: PortField) {
        if let port = Int(portFieldText.trimmingCharacters(in: .whitespaces)) {
            switch field {
            case .socks: store.settings.socksPort = port
            case .http:  store.settings.httpPort = port
            }
        }
        editingPortField = nil
    }
}
