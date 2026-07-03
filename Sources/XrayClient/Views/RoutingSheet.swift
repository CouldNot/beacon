import SwiftUI

/// Professional routing configuration: preset selection, geo .dat source +
/// downloader, ad-block toggle, and a full rule editor (v2rayN-style) for the
/// custom preset.
struct RoutingSheet: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(Loc.self) private var loc
    @Environment(\.dismiss) private var dismiss

    private var geo = GeoAssetManager.shared

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(loc("Routing")).font(.title2).bold()
                Spacer()
                Button(loc("Done")) { applyAndDismiss() }
                    .keyboardShortcut(.defaultAction)
                    .glassProminentButton()
            }
            .padding()
            Divider()

            Form {
                presetSection
                geoSection
                if store.settings.routingPreset == .custom {
                    customRulesSection
                }
                if connection.isConnected {
                    Section {
                        Text(loc("Reconnect to apply routing changes."))
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 560, height: 640)
    }

    // MARK: - Preset

    private var presetSection: some View {
        @Bindable var store = store
        return Section(loc("Mode")) {
            Picker(loc("Preset"), selection: $store.settings.routingPreset) {
                ForEach(RoutingPreset.allCases) { p in Text(p.title).tag(p) }
            }
            .onChange(of: store.settings.routingPreset) { _, _ in store.save() }
            Text(store.settings.routingPreset.subtitle)
                .font(.caption).foregroundStyle(.secondary)

            Toggle(loc("Block ads & trackers"), isOn: $store.settings.blockAds)
                .onChange(of: store.settings.blockAds) { _, _ in store.save() }
        }
    }

    // MARK: - Geo assets

    private var geoSection: some View {
        @Bindable var store = store
        let needsGeo = store.settings.routingPreset.needsGeoAssets
            || store.settings.blockAds
            || usesGeoInCustom
        return Section {
            Picker(loc("Rule database"), selection: $store.settings.geoSource) {
                ForEach(GeoAssetSource.allCases) { s in Text(s.title).tag(s) }
            }
            .onChange(of: store.settings.geoSource) { _, _ in store.save() }

            if store.settings.geoSource == .custom {
                TextField("geoip.dat URL", text: $store.settings.customGeoipURL)
                    .onChange(of: store.settings.customGeoipURL) { _, _ in store.save() }
                TextField("geosite.dat URL", text: $store.settings.customGeositeURL)
                    .onChange(of: store.settings.customGeositeURL) { _, _ in store.save() }
            }

            HStack {
                if geo.isDownloading {
                    ProgressView().controlSize(.small)
                    Text(loc("Downloading…")).font(.caption).foregroundStyle(.secondary)
                } else if geo.hasAssets, let updated = geo.lastUpdated {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("\(loc("Updated")) \(updated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(loc("Not downloaded")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(geo.hasAssets ? loc("Update") : loc("Download")) {
                    Task { await downloadGeo() }
                }
                .glassButton()
                .disabled(geo.isDownloading)
            }
            if let err = geo.lastError {
                Text(err).font(.caption2).foregroundStyle(.red)
            }
            if needsGeo && !geo.hasAssets {
                Text(loc("This preset needs the rule database. Download it to use geosite/geoip rules."))
                    .font(.caption2).foregroundStyle(.orange)
            }
        } header: {
            Text(loc("Rule database (geosite / geoip)"))
        } footer: {
            Text(loc("Downloaded from GitHub. geosite matches domains, geoip matches IPs by country."))
                .font(.caption2)
        }
    }

    // MARK: - Custom rule editor

    private var customRulesSection: some View {
        @Bindable var store = store
        return Section {
            if store.settings.customRules.isEmpty {
                Text(loc("No custom rules. Add one below."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach($store.settings.customRules) { $rule in
                RuleCard(rule: $rule, onChange: { store.save() }, onDelete: { id in
                    store.settings.customRules.removeAll { $0.id == id }
                    store.save()
                })
            }
            .onMove { indices, dest in
                store.settings.customRules.move(fromOffsets: indices, toOffset: dest)
                store.save()
            }

            Button {
                store.settings.customRules.append(RoutingRule(name: "New rule"))
                store.save()
            } label: {
                Label(loc("Add rule"), systemImage: "plus.circle")
            }
        } header: {
            Text(loc("Custom rules (top to bottom, first match wins)"))
        } footer: {
            Text(loc("Domains: example.com, domain:example.com, geosite:category-ads-all, keyword:google. IPs: 1.2.3.0/24, geoip:cn, geoip:private."))
                .font(.caption2)
        }
    }

    private var usesGeoInCustom: Bool {
        store.settings.routingPreset == .custom
            && store.settings.customRules.contains { r in
                r.domains.contains { $0.hasPrefix("geosite:") }
                    || r.ips.contains { $0.hasPrefix("geoip:") }
            }
    }

    // MARK: - Actions

    private func downloadGeo() async {
        await geo.download(source: store.settings.geoSource,
                           customGeoip: store.settings.customGeoipURL,
                           customGeosite: store.settings.customGeositeURL)
    }

    private func applyAndDismiss() {
        connection.routingRules = store.settings.effectiveRoutingRules
        store.save()
        dismiss()
    }
}

// MARK: - Single rule editor card

private struct RuleCard: View {
    @Binding var rule: RoutingRule
    @Environment(Loc.self) private var loc
    var onChange: () -> Void
    var onDelete: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("", isOn: $rule.enabled)
                    .labelsHidden()
                    .onChange(of: rule.enabled) { _, _ in onChange() }
                TextField(loc("Rule name"), text: $rule.name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: rule.name) { _, _ in onChange() }
                Picker("", selection: $rule.outbound) {
                    ForEach(RuleOutbound.allCases) { o in Text(o.title).tag(o) }
                }
                .labelsHidden().fixedSize()
                .onChange(of: rule.outbound) { _, _ in onChange() }
                let ruleID = rule.id
                Button(role: .destructive) { onDelete(ruleID) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            matcherField(title: loc("Domains"), binding: domainsBinding)
            matcherField(title: loc("IPs / CIDR"), binding: ipsBinding)
            HStack {
                Text(loc("Port")).font(.caption).foregroundStyle(.secondary)
                TextField("443 or 1000-2000", text: $rule.port)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: rule.port) { _, _ in onChange() }
            }
        }
        .padding(.vertical, 4)
        .opacity(rule.enabled ? 1 : 0.5)
    }

    private func matcherField(title: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            TextEditor(text: binding)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 48)
                .padding(2)
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        }
    }

    private var domainsBinding: Binding<String> {
        Binding(
            get: { rule.domains.joined(separator: "\n") },
            set: { rule.domains = RuleCard.split($0); onChange() }
        )
    }

    private var ipsBinding: Binding<String> {
        Binding(
            get: { rule.ips.joined(separator: "\n") },
            set: { rule.ips = RuleCard.split($0); onChange() }
        )
    }

    private static func split(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isNewline || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
