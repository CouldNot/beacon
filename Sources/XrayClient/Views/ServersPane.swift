import SwiftUI

// MARK: - Servers pane

/// The Servers destination, restyled to the redesign mockup: a connection
/// status card up top (active server, latency, protocol, uptime, Disconnect),
/// then one collapsible section per subscription whose rows live on a shared
/// glass panel — flag, name, address · protocol, signal bars, latency, and a
/// per-row actions menu.
struct ServersPane: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc

    /// Owned by the window shell so the titlebar search button can toggle it.
    @Binding var searchVisible: Bool

    @AppStorage("serversSortMode") private var sortModeRaw = ServerSortMode.latency.rawValue
    @AppStorage("serversAliveOnly") private var aliveOnly = false

    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var showSubSheet = false
    /// Server whose QR code is currently being shown (drives the QR sheet).
    @State private var qrServer: ProxyConfig?
    /// Server currently open in the per-server edit sheet.
    @State private var editServer: ProxyConfig?

    @FocusState private var searchFocused: Bool
    /// Drives keyboard focus so arrow keys / Enter target the server list.
    @FocusState private var listFocused: Bool

    private var sortMode: ServerSortMode {
        ServerSortMode(rawValue: sortModeRaw) ?? .latency
    }

    /// True when the active tunnel is TUN — ping probes need host-routes then.
    private var tunActive: Bool {
        connection.mode == .tun && connection.isConnected
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if searchVisible { searchBar }
                    ConnectionStatusCard()
                    if store.subscriptions.isEmpty {
                        emptyState
                    }
                    ForEach(Array(store.subscriptions.enumerated()), id: \.element.id) { idx, sub in
                        groupSection(sub, isFirst: idx == 0)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            // Keep the keyboard-selected row visible as it moves.
            .onChange(of: store.selectedServerID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        // Make the list the keyboard focus target and wire arrow keys + Enter.
        .focusable()
        .focusEffectDisabled()
        .focused($listFocused)
        .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
        .onKeyPress(.return) { connectSelected(); return .handled }
        .onAppear { listFocused = true }
        .onChange(of: searchVisible) { _, visible in
            if visible {
                searchFocused = true
            } else {
                searchText = ""
                listFocused = true
            }
        }
        .animation(.easeInOut(duration: 0.18), value: searchVisible)
        .sheet(isPresented: $showAddSheet) { AddServerSheet() }
        .sheet(isPresented: $showSubSheet) { SubscriptionSheet() }
        .sheet(item: $qrServer) { server in QRDisplaySheet(server: server) }
        .sheet(item: $editServer) { server in
            EditServerSheet(server: server)
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(loc("Search servers…"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onExitCommand { searchVisible = false }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassCard(radius: DS.Radius.card)
    }

    // MARK: - Groups

    /// Filter + sort applied to every group's servers: search text, the
    /// reachable-only filter, then the chosen sort order (stable).
    private func visibleServers(in servers: [ProxyConfig]) -> [ProxyConfig] {
        var list = servers
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(q) || $0.address.lowercased().contains(q)
            }
        }
        if aliveOnly {
            list = list.filter { (pinger.latency(for: $0.id) ?? nil) != nil }
        }
        switch sortMode {
        case .standard:
            break
        case .latency:
            // Untested/unreachable servers sink to the bottom; ties keep their
            // subscription order (stable via index tiebreak).
            list = list.enumerated()
                .sorted {
                    let la = (pinger.latency(for: $0.element.id) ?? nil) ?? Int.max
                    let lb = (pinger.latency(for: $1.element.id) ?? nil) ?? Int.max
                    return la == lb ? $0.offset < $1.offset : la < lb
                }
                .map(\.element)
        case .name:
            list.sort {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
        return list
    }

    /// Servers in on-screen order across all groups, honouring collapse state
    /// and the active filters — the order the up/down arrow keys walk through.
    private var navigableServers: [ProxyConfig] {
        store.subscriptions.flatMap { sub in
            sub.isCollapsed ? [] : visibleServers(in: sub.servers)
        }
    }

    @ViewBuilder
    private func groupSection(_ sub: Subscription, isFirst: Bool) -> some View {
        let visible = visibleServers(in: sub.servers)
        // Hide groups entirely filtered out by an active search/alive filter.
        let hidden = (!searchText.isEmpty || aliveOnly) && visible.isEmpty
        if !hidden {
            VStack(alignment: .leading, spacing: 10) {
                groupHeader(sub, isFirst: isFirst)
                if !sub.isCollapsed {
                    if visible.isEmpty {
                        Text(loc("No servers in this group."))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 22)
                            .glassCard(radius: DS.Radius.panel)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(visible) { server in
                                serverRow(server, in: sub)
                                if server.id != visible.last?.id {
                                    Divider()
                                        .opacity(0.4)
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .glassCard(radius: DS.Radius.panel)
                    }
                }
            }
        }
    }

    private func groupHeader(_ sub: Subscription, isFirst: Bool) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.toggleCollapsed(id: sub.id)
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(sub.isCollapsed ? -90 : 0))
                    Text(sub.isManual ? loc("Manual") : sub.name)
                        .font(.system(size: 15, weight: .bold))
                    Text("\(sub.servers.count)")
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let traffic = trafficSummary(sub) {
                Text(traffic)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !sub.isManual {
                subscriptionMenu(sub)
            }
            if isFirst {
                sortMenu
                addMenu
            }
        }
        .padding(.horizontal, 2)
    }

    /// One-line traffic/expiry summary for subscription groups that report it.
    private func trafficSummary(_ sub: Subscription) -> String? {
        var parts: [String] = []
        if let used = sub.usedBytes, let total = sub.totalBytes {
            parts.append("\(ByteFormat.string(used)) / \(ByteFormat.string(total))")
        }
        if let exp = sub.expiresAt {
            parts.append(loc("until") + " " + exp.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.isEmpty ? nil : "· " + parts.joined(separator: " · ")
    }

    private func subscriptionMenu(_ sub: Subscription) -> some View {
        // Can't remove a subscription that holds the active server.
        let holdsActive = connection.isConnected
            && sub.servers.contains { $0.id == connection.activeServerID }
        return Menu {
            Button(loc("Refresh Now")) {
                Task { await SubscriptionService.refresh(sub, into: store) }
            }
            Toggle(loc("Auto-update"), isOn: Binding(
                get: { sub.autoUpdate },
                set: { store.setAutoUpdate($0, id: sub.id) }
            ))
            Divider()
            Button(loc("Remove"), role: .destructive) {
                store.removeSubscription(id: sub.id)
            }
            .disabled(holdsActive)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Sort selector styled as the mockup's "⇅ Latency" glass chip, with the
    /// reachable-only filter folded in.
    private var sortMenu: some View {
        Menu {
            Picker(loc("Sort by"), selection: Binding(
                get: { sortMode },
                set: { sortModeRaw = $0.rawValue }
            )) {
                ForEach(ServerSortMode.allCases) { mode in
                    Text(loc(mode.title)).tag(mode)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Toggle(loc("Reachable Only"), isOn: $aliveOnly)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 34, height: 34)
        .glassCircle()
        .fixedSize()
        .help(loc(sortMode.title))
    }

    /// Native pull-down menu: paste a link or add a subscription.
    private var addMenu: some View {
        Menu {
            Button(loc("Paste Link…")) { showAddSheet = true }
            Button(loc("Add Subscription…")) { showSubSheet = true }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 34, height: 34)
        .glassCircle()
        .fixedSize()
        .help(loc("Add servers"))
    }

    // MARK: - Rows

    private func serverRow(_ server: ProxyConfig, in sub: Subscription) -> some View {
        let isActive = connection.activeServerID == server.id && connection.isConnected
        return ServerRowView(
            server: server,
            isSelected: store.selectedServerID == server.id,
            isActive: isActive,
            latency: pinger.latency(for: server.id),
            isTesting: pinger.isTesting(server.id),
            isConnected: connection.isConnected,
            canDelete: sub.isManual && !isActive,
            onSelect: { handleTap(server) },
            onConnect: { store.select(server.id); connection.connect(to: server) },
            onPing: { pinger.test([server], tunActive: tunActive) },
            onCopy: {
                let link = LinkBuilder.link(for: server)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link, forType: .string)
            },
            onQR: { qrServer = server },
            onEdit: { editServer = server },
            onDelete: { store.removeServer(id: server.id) }
        )
        .id(server.id)
    }

    /// Disconnected: tap = select only. Connected: tap = switch immediately.
    private func handleTap(_ server: ProxyConfig) {
        store.select(server.id)
        if connection.isConnected {
            connection.connect(to: server)
        }
    }

    // MARK: - Keyboard navigation

    /// Moves the selection up or down the visible list. Selecting a server
    /// while connected switches to it immediately (matching tap behaviour);
    /// while disconnected it just highlights, and Enter connects.
    private func moveSelection(by delta: Int) {
        let list = navigableServers
        guard !list.isEmpty else { return }
        let currentIdx = list.firstIndex { $0.id == store.selectedServerID }
        let nextIdx: Int
        if let currentIdx {
            nextIdx = min(max(currentIdx + delta, 0), list.count - 1)
        } else {
            // No selection yet: down picks the first, up picks the last.
            nextIdx = delta > 0 ? 0 : list.count - 1
        }
        store.select(list[nextIdx].id)
    }

    /// Connects to the currently-selected server (Enter / Return).
    private func connectSelected() {
        if let s = store.server(withID: store.selectedServerID) {
            connection.connect(to: s)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(loc("No servers yet")).font(.headline)
            Text(loc("Add a subscription or paste a link to get started."))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(loc("Add Subscription")) { showSubSheet = true }
                    .glassButton()
                Button(loc("Paste Link")) { showAddSheet = true }
                    .glassProminentButton()
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .glassCard(radius: DS.Radius.panel)
    }
}

// MARK: - Sort mode

/// User-selectable ordering for the server lists.
enum ServerSortMode: String, CaseIterable, Identifiable {
    case latency
    case name
    case standard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .latency:  return "Latency"
        case .name:     return "Name"
        case .standard: return "Default"
        }
    }
}

// MARK: - Connection status card

/// The mockup's status banner: radio tile, flag + active/selected server name,
/// a status line (state · latency · protocol / security · uptime), and the
/// Connect/Disconnect action.
private struct ConnectionStatusCard: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc

    /// The server the card describes: the active one while connected (or
    /// connecting), otherwise the list selection.
    private var shownServer: ProxyConfig? {
        if connection.isConnected, let active = store.server(withID: connection.activeServerID) {
            return active
        }
        return store.server(withID: store.selectedServerID)
    }

    var body: some View {
        HStack(spacing: 14) {
            iconTile
            VStack(alignment: .leading, spacing: 3) {
                titleLine
                statusLine
            }
            Spacer(minLength: 12)
            actionButton
        }
        .padding(16)
        .glassCard(radius: DS.Radius.panel)
    }

    private var iconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(statusColor.opacity(connection.isConnected ? 0.16 : 0.10))
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .frame(width: 46, height: 46)
    }

    private var titleLine: some View {
        HStack(spacing: 7) {
            if let server = shownServer {
                Text(ServerFlag.split(server.name).rest)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
            } else {
                Text(loc("No Server Selected"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(statusColor)
            Text(detailText)
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var statusLabel: String {
        switch connection.state {
        case .connected:     return loc("Connected")
        case .connecting:    return loc("Connecting…")
        case .failed:        return loc("Failed")
        case .disconnected:  return loc("Not Connected")
        }
    }

    /// " · 24 ms · VLESS / Reality · up 01:12:44" — only the parts we know.
    private var detailText: String {
        var parts: [String] = []
        if let server = shownServer {
            if connection.isConnected,
               let ms = pinger.latency(for: server.id) ?? nil {
                parts.append("\(ms) ms")
            }
            var proto = server.proto.displayName
            if let sec = server.security.displayName {
                proto += " / \(sec)"
            }
            parts.append(proto)
        }
        if connection.isConnected, !connection.uptimeText.isEmpty {
            parts.append(loc("up") + " " + connection.uptimeText)
        }
        if case .failed(let message) = connection.state {
            parts.append(message)
        }
        return parts.isEmpty ? "" : "· " + parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var actionButton: some View {
        if connection.isConnected || connection.state == .connecting {
            Button(loc("Disconnect")) { connection.disconnect() }
                .glassButton()
                .controlSize(.large)
        } else {
            Button {
                if let server = shownServer { connection.connect(to: server) }
            } label: {
                Text(loc("Connect")).frame(minWidth: 72)
            }
            .glassProminentButton()
            .controlSize(.large)
            .disabled(shownServer == nil)
        }
    }

    private var statusColor: Color {
        switch connection.state {
        case .connected:    return .green
        case .connecting:   return .orange
        case .failed:       return .red
        case .disconnected: return .secondary
        }
    }
}

// MARK: - Server row

/// One row on the servers panel: flag, name, "address · protocol", signal
/// bars + latency, a gear actions menu, and a green radio badge when active.
private struct ServerRowView: View {
    @Environment(Loc.self) private var loc

    let server: ProxyConfig
    let isSelected: Bool
    let isActive: Bool
    let latency: Int??     // outer nil = untested; inner nil = unreachable
    let isTesting: Bool
    let isConnected: Bool
    let canDelete: Bool
    let onSelect: () -> Void
    let onConnect: () -> Void
    let onPing: () -> Void
    let onCopy: () -> Void
    let onQR: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                Text(ServerFlag.split(server.name).rest)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text("\(server.address) · \(server.proto.displayName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            latencyView
            actionsMenu
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(rowBackground)
        .onTapGesture(count: 2) { onConnect() }
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .contextMenu { menuItems }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isActive {
            Color.primary.opacity(0.07)
        } else if isSelected {
            Color.primary.opacity(0.10)
        } else if isHovering {
            Color.primary.opacity(0.04)
        }
    }

    /// Leading connection indicator: green when this server is the active
    /// tunnel, a muted gray otherwise.
    private var statusDot: some View {
        Circle()
            .fill(isActive ? Color.green : Color.secondary.opacity(0.35))
            .frame(width: 8, height: 8)
            .frame(width: 18)
    }

    @ViewBuilder
    private var latencyView: some View {
        if isTesting {
            ProgressView().controlSize(.small)
        } else if let outer = latency {
            if let ms = outer {
                HStack(spacing: 8) {
                    Image(systemName: "cellularbars", variableValue: signalLevel(ms))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("\(ms) ms")
                        .monoNumeric(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 48, alignment: .trailing)
                }
            } else {
                Text(loc("timeout"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsMenu: some View {
        Menu {
            menuItems
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var menuItems: some View {
        Button(isConnected ? loc("Switch Here") : loc("Connect")) { onConnect() }
            .disabled(isActive)
        Button(loc("Test Ping")) { onPing() }
        Divider()
        Button(loc("Edit…")) { onEdit() }
        Button(loc("Copy Link")) { onCopy() }
        Button(loc("Show QR Code")) { onQR() }
        if canDelete {
            Divider()
            Button(loc("Delete"), role: .destructive) { onDelete() }
        }
    }

    /// Maps latency to the 4-step `cellularbars` fill.
    private func signalLevel(_ ms: Int) -> Double {
        switch ms {
        case ..<80:   return 1.0
        case ..<160:  return 0.75
        case ..<320:  return 0.5
        default:      return 0.25
        }
    }
}

// MARK: - Titlebar controls (refresh / search)

/// The glass capsule at the trailing edge of the titlebar strip: a refresh
/// button (re-fetches subscriptions and re-pings every server) and a search
/// toggle, mirroring the header pill on the leading side.
struct ServersTitleBarControls: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc

    @Binding var searchVisible: Bool
    @State private var isRefreshing = false

    var body: some View {
        HStack(spacing: 0) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 38, height: 34)
            } else {
                PillIconButton(systemImage: "arrow.clockwise") {
                    refresh()
                }
                .disabled(store.allServers.isEmpty)
                .help(loc("Refresh subscriptions and retest latency"))
            }

            Divider()
                .frame(height: 16)

            PillIconButton(systemImage: "magnifyingglass", isActive: searchVisible) {
                searchVisible.toggle()
            }
            .help(loc("Search servers"))
        }
        .frame(height: 34)
        .glassPill()
    }

    private func refresh() {
        isRefreshing = true
        let tunActive = connection.mode == .tun && connection.isConnected
        Task {
            await SubscriptionService.refreshAll(store)
            pinger.test(store.allServers, tunActive: tunActive)
            isRefreshing = false
        }
    }
}

// MARK: - Display names

extension ProxyProtocol {
    /// Human-facing protocol name (list subtitles, status card).
    var displayName: String {
        switch self {
        case .vless:       return "VLESS"
        case .vmess:       return "VMess"
        case .trojan:      return "Trojan"
        case .shadowsocks: return "Shadowsocks"
        case .hysteria2:   return "Hysteria2"
        case .tuic:        return "TUIC"
        case .wireguard:   return "WireGuard"
        case .anytls:      return "AnyTLS"
        }
    }
}

extension StreamSecurity {
    /// Human-facing security name, nil when there is nothing worth showing.
    var displayName: String? {
        switch self {
        case .none:    return nil
        case .tls:     return "TLS"
        case .reality: return "Reality"
        }
    }
}

// MARK: - Country flags

/// Derives an emoji flag for a server row. Subscription names often embed a
/// flag emoji already; otherwise a small city/country lookup covers the common
/// VPN locations. Purely cosmetic — rows without a match get a globe icon.
enum ServerFlag {
    /// Splits a server name into its flag (if any) and the remaining text.
    static func split(_ name: String) -> (flag: String?, rest: String) {
        if let (flag, rest) = extractEmbeddedFlag(name) {
            return (flag, rest)
        }
        return (inferredFlag(for: name), name)
    }

    /// Finds a regional-indicator pair (🇩🇪 etc.) anywhere in the name and
    /// returns it plus the name with the flag removed.
    private static func extractEmbeddedFlag(_ name: String) -> (String, String)? {
        let range = 0x1F1E6...0x1F1FF
        let scalars = Array(name.unicodeScalars)
        for i in scalars.indices.dropLast() {
            if range.contains(Int(scalars[i].value)),
               range.contains(Int(scalars[i + 1].value)) {
                let flag = String(String.UnicodeScalarView(scalars[i...i + 1]))
                var rest = scalars
                rest.removeSubrange(i...i + 1)
                let restString = String(String.UnicodeScalarView(rest))
                    .trimmingCharacters(in: .whitespaces)
                return (flag, restString.isEmpty ? name : restString)
            }
        }
        return nil
    }

    /// Builds the emoji flag for an ISO 3166-1 alpha-2 country code.
    private static func flag(forCode code: String) -> String {
        String(String.UnicodeScalarView(
            code.uppercased().unicodeScalars.compactMap {
                Unicode.Scalar(0x1F1E6 + $0.value - Unicode.Scalar("A").value)
            }
        ))
    }

    /// City / country / code → ISO code. Names ≥ 4 chars match as substrings;
    /// 2–3 char codes only match as standalone words to avoid false positives
    /// ("in" inside "Singapore").
    private static let keywords: [String: String] = [
        // Cities
        "frankfurt": "DE", "berlin": "DE", "munich": "DE",
        "amsterdam": "NL", "london": "GB", "manchester": "GB",
        "new york": "US", "los angeles": "US", "chicago": "US",
        "dallas": "US", "seattle": "US", "miami": "US", "silicon": "US",
        "san jose": "US", "ashburn": "US", "phoenix": "US",
        "singapore": "SG", "tokyo": "JP", "osaka": "JP",
        "hong kong": "HK", "hongkong": "HK", "seoul": "KR",
        "paris": "FR", "marseille": "FR", "moscow": "RU",
        "dubai": "AE", "sydney": "AU", "melbourne": "AU",
        "toronto": "CA", "vancouver": "CA", "montreal": "CA",
        "mumbai": "IN", "delhi": "IN", "bangalore": "IN",
        "zurich": "CH", "geneva": "CH", "stockholm": "SE",
        "warsaw": "PL", "madrid": "ES", "barcelona": "ES",
        "milan": "IT", "rome": "IT", "istanbul": "TR",
        "taipei": "TW", "kuala lumpur": "MY", "jakarta": "ID",
        "bangkok": "TH", "hanoi": "VN", "saigon": "VN",
        "dublin": "IE", "vienna": "AT", "prague": "CZ",
        "helsinki": "FI", "oslo": "NO", "copenhagen": "DK",
        "lisbon": "PT", "brussels": "BE", "bucharest": "RO",
        "kyiv": "UA", "kiev": "UA", "tel aviv": "IL",
        "johannesburg": "ZA", "cairo": "EG", "buenos aires": "AR",
        "santiago": "CL", "auckland": "NZ", "sao paulo": "BR",
        "reykjavik": "IS", "riga": "LV", "vilnius": "LT",
        "tallinn": "EE", "sofia": "BG", "budapest": "HU",
        "athens": "GR", "luxembourg": "LU",
        // Countries
        "germany": "DE", "netherlands": "NL", "united kingdom": "GB",
        "britain": "GB", "england": "GB", "united states": "US",
        "america": "US", "japan": "JP", "korea": "KR", "france": "FR",
        "russia": "RU", "australia": "AU", "canada": "CA", "india": "IN",
        "switzerland": "CH", "sweden": "SE", "poland": "PL", "spain": "ES",
        "italy": "IT", "turkey": "TR", "taiwan": "TW", "malaysia": "MY",
        "indonesia": "ID", "thailand": "TH", "vietnam": "VN",
        "ireland": "IE", "austria": "AT", "finland": "FI", "norway": "NO",
        "denmark": "DK", "portugal": "PT", "belgium": "BE", "brazil": "BR",
        "mexico": "MX", "argentina": "AR", "israel": "IL", "iceland": "IS",
        "ukraine": "UA", "czech": "CZ", "romania": "RO", "hungary": "HU",
        "greece": "GR", "bulgaria": "BG",
        // Short codes (word-boundary matched)
        "de": "DE", "us": "US", "usa": "US", "uk": "GB", "gb": "GB",
        "jp": "JP", "sg": "SG", "hk": "HK", "nl": "NL", "fr": "FR",
        "kr": "KR", "tw": "TW", "ru": "RU", "ca": "CA", "au": "AU",
        "ch": "CH", "se": "SE", "es": "ES", "it": "IT", "tr": "TR",
        "my": "MY", "th": "TH", "vn": "VN", "br": "BR", "ae": "AE",
    ]

    private static func inferredFlag(for name: String) -> String? {
        let lower = name.lowercased()
        // Longer keys first so "new york" beats a stray "york"-like token.
        for (key, code) in keywords.sorted(by: { $0.key.count > $1.key.count }) {
            if key.count >= 4 {
                if lower.contains(key) { return flag(forCode: code) }
            } else {
                // Standalone word match for the 2–3 letter codes.
                let tokens = lower.split { !$0.isLetter }
                if tokens.contains(Substring(key)) { return flag(forCode: code) }
            }
        }
        return nil
    }
}
