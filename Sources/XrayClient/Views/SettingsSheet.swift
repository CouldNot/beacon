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

    var body: some View {
        @Bindable var store = store
        Form {
                Section(loc("Tunnel")) {
                    Picker(loc("Mode"), selection: $store.settings.mode) {
                        ForEach(TunnelMode.allCases) { m in Text(m.title).tag(m) }
                    }
                    .onChange(of: store.settings.mode) { _, m in
                        connection.mode = m; store.save()
                    }
                    Text(store.settings.mode.subtitle)
                        .font(.caption).foregroundStyle(.secondary)

                    HStack {
                        Text(loc("SOCKS port"))
                        Spacer()
                        TextField("", value: $store.settings.socksPort, format: .number.grouping(.never))
                            .frame(width: 80).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(loc("HTTP port"))
                        Spacer()
                        TextField("", value: $store.settings.httpPort, format: .number.grouping(.never))
                            .frame(width: 80).multilineTextAlignment(.trailing)
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
                        Image(systemName: helperInstalled ? "checkmark.shield.fill" : "shield.slash")
                            .foregroundStyle(helperInstalled ? .green : .secondary)
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
                    Stepper(value: $store.settings.autoUpdateIntervalHours, in: 1...168) {
                        Text("Every \(store.settings.autoUpdateIntervalHours) h")
                    }
                    .onChange(of: store.settings.autoUpdateIntervalHours) { _, _ in store.save() }
                    Toggle(loc("Send HWID with subscription requests"), isOn: $store.settings.sendHwid)
                        .onChange(of: store.settings.sendHwid) { _, _ in store.save() }
                    Text(loc("Identifies this device to providers that require it."))
                        .font(.caption).foregroundStyle(.secondary)
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
        .onChange(of: store.settings.socksPort) { _, p in
            connection.ports.socks = p; store.save()
        }
        .onChange(of: store.settings.httpPort) { _, p in
            connection.ports.http = p; store.save()
        }
    }
}
