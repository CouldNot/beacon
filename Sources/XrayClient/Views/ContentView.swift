import SwiftUI

// MARK: - Window shell

/// Top-level window shell: a native split view with a translucent sidebar
/// (Servers / Log / Settings) and the selected pane in the detail column.
/// Traffic-light buttons float over the sidebar and the sidebar toggle lives in
/// the toolbar, matching the redesign's macOS-native structure.
struct ContentView: View {
    @Environment(ServerStore.self) private var store
    @AppStorage("sidebarSelection") private var selectionRaw = SidebarItem.servers.rawValue

    private var selection: Binding<SidebarItem> {
        Binding(
            get: { SidebarItem(rawValue: selectionRaw) ?? .servers },
            set: { selectionRaw = $0.rawValue }
        )
    }

    var body: some View {
        // Custom two-column layout instead of NavigationSplitView: on macOS 26
        // the system split view floats the sidebar as its own rounded glass
        // slab, which breaks the seamless Reeder-style look. Here ONE flat
        // vibrancy surface spans the entire window and the columns are just
        // transparent content over it, separated by a plain hairline.
        HStack(spacing: 0) {
            Sidebar(selection: selection, serverCount: store.allServers.count)
                .frame(width: 220)

            // Detail column intentionally empty while panes are rebuilt on the
            // new shell (tasks 3-5).
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VisualEffectBackground(material: .sidebar).ignoresSafeArea())
        .background(WindowConfigurator())
        .overlay(alignment: .leading) {
            // Hairline drawn as an overlay so it renders above the vibrancy
            // material and extends into the title bar via ignoresSafeArea.
            HStack(spacing: 0) {
                Color.clear.frame(width: 220)
                Color(nsColor: .separatorColor).frame(width: 1)
            }
            .ignoresSafeArea()
        }
    }
}

/// The three destinations in the sidebar.
enum SidebarItem: String, CaseIterable, Identifiable {
    case servers, log, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .servers:  return "Servers"
        case .log:      return "Log"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .servers:  return "globe"
        case .log:      return "waveform.path"
        case .settings: return "gearshape"
        }
    }
}

/// Flat sidebar column drawn directly on the shared window material - no List,
/// no separate background, so it is indistinguishable from the detail side.
/// Rows are simple buttons with a rounded selection highlight.
struct Sidebar: View {
    @Environment(Loc.self) private var loc
    @Binding var selection: SidebarItem
    let serverCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SidebarItem.allCases) { item in
                SidebarRow(
                    title: loc(item.title),
                    systemImage: item.systemImage,
                    badge: item == .servers && serverCount > 0 ? "\(serverCount)" : nil,
                    isSelected: selection == item
                ) {
                    selection = item
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        // Clear the traffic-light buttons at the top of the window.
        .padding(.top, 52)
    }
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(.quaternary)
                      : isHovering ? AnyShapeStyle(.quaternary.opacity(0.5))
                      : AnyShapeStyle(.clear))
        )
        .onHover { isHovering = $0 }
    }
}

// MARK: - Servers pane

/// The Servers destination: status header, search/filter bar, the collapsible
/// server list, and the action footer. (Restyled to the mockup in a later step.)
struct ServersPane: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc

    @State private var showAddSheet = false
    @State private var showSubSheet = false
    @State private var isRefreshing = false
    @State private var searchText = ""
    @State private var aliveOnly = false
    @State private var sortByPing = false
    /// IDs selected for multi-delete in the Manual group.
    @State private var selectedForDeletion: Set<UUID> = []
    @State private var selectionMode = false

    /// True when the active tunnel is TUN — ping probes need host-routes then.
    private var tunActive: Bool {
        connection.mode == .tun && connection.isConnected
    }

    /// Drives keyboard focus so arrow keys / Enter target the server list.
    @FocusState private var listFocused: Bool

    /// Servers in on-screen order across all groups, honouring collapse state,
    /// search text, the alive filter, and ping sort. This is the order the
    /// up/down arrow keys walk through.
    private var navigableServers: [ProxyConfig] {
        store.subscriptions.flatMap { sub -> [ProxyConfig] in
            sub.isCollapsed ? [] : Self.filterServers(
                sub.servers, search: searchText, aliveOnly: aliveOnly,
                sortByPing: sortByPing, pinger: pinger)
        }
    }

    /// Shared filter/sort used by both the keyboard navigation order and the
    /// per-group views, so the two never drift apart.
    static func filterServers(_ servers: [ProxyConfig], search: String,
                              aliveOnly: Bool, sortByPing: Bool,
                              pinger: PingTester) -> [ProxyConfig] {
        var list = servers
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.name.lowercased().contains(q)
                || $0.address.lowercased().contains(q) }
        }
        if aliveOnly {
            list = list.filter {
                if let outer = pinger.latency(for: $0.id), outer != nil { return true }
                return false
            }
        }
        if sortByPing {
            list.sort { a, b in
                let la = (pinger.latency(for: a.id) ?? nil) ?? Int.max
                let lb = (pinger.latency(for: b.id) ?? nil) ?? Int.max
                return la < lb
            }
        }
        return list
    }

    /// Moves the selection up or down the visible list. Selecting a server while
    /// connected switches to it immediately (matching tap behaviour); while
    /// disconnected it just highlights, and Enter connects.
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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            serverList
            Divider()
            footer
        }
        .navigationTitle(loc("Servers"))
        .sheet(isPresented: $showAddSheet) { AddServerSheet() }
        .sheet(isPresented: $showSubSheet) { SubscriptionSheet() }
    }

    // MARK: - Search & filter

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search servers…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            Divider().frame(height: 16)
            Toggle("Alive", isOn: $aliveOnly)
                .glassToggle().controlSize(.small)
                .help("Show only servers that responded to the last ping test")
            Toggle("By ping", isOn: $sortByPing)
                .glassToggle().controlSize(.small)
                .help("Sort servers by latency within each group")
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
    }

    // MARK: - Header (status + connect)

    private var header: some View {
        let selected = store.server(withID: store.selectedServerID)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(statusColor.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: connection.isConnected ? "shield.lefthalf.filled" : "shield.slash")
                    .font(.system(size: 20))
                    .foregroundStyle(statusColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.state.label)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                if connection.isConnected {
                    Text("\(connection.activeServerName) · \(connection.uptimeText)")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if let selected {
                    Text(selected.name).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Select a server").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            modePicker
            connectButton(selected: selected)
        }
        .padding(14)
    }

    private var modePicker: some View {
        @Bindable var conn = connection
        return ModeGlassSwitch(
            mode: $conn.mode,
            isDisabled: connection.isConnected
        ) { newMode in
            store.settings.mode = newMode
            store.save()
        }
        .help(connection.mode.subtitle)
    }

    @ViewBuilder
    private func connectButton(selected: ProxyConfig?) -> some View {
        if connection.isConnected || connection.state == .connecting {
            Button(role: .destructive) { connection.disconnect() } label: {
                Label("Disconnect", systemImage: "stop.fill").frame(minWidth: 96)
            }
            .controlSize(.large).glassProminentButton().tint(.red)
        } else {
            Button {
                if let s = selected { connection.connect(to: s) }
            } label: {
                Label("Connect", systemImage: "bolt.fill").frame(minWidth: 96)
            }
            .controlSize(.large).glassProminentButton()
            .disabled(selected == nil)
        }
    }

    // MARK: - Server list (collapsible groups)

    private var serverList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if store.subscriptions.isEmpty {
                        emptyState
                    }
                    ForEach(store.subscriptions) { sub in
                        SubscriptionGroupView(
                            subscription: sub,
                            searchText: searchText,
                            aliveOnly: aliveOnly,
                            sortByPing: sortByPing,
                            selectionMode: selectionMode && sub.isManual,
                            selectedForDeletion: $selectedForDeletion
                        )
                    }
                }
                .padding(12)
            }
            .frame(minHeight: 80, maxHeight: .infinity)
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
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 34)).foregroundStyle(.secondary)
            Text(loc("No servers yet")).font(.headline)
            Text(loc("Add a subscription or paste a link to get started."))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(loc("Add Subscription")) { showSubSheet = true }
                    .glassButton()
                Button(loc("Paste Link")) { showAddSheet = true }
                    .glassProminentButton()
            }.padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    // MARK: - Footer (toolbar)

    private var hasManualServers: Bool {
        store.subscriptions.contains { $0.isManual && !$0.servers.isEmpty }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if selectionMode { deletionBar }
            HStack(spacing: 12) {
                Button { showSubSheet = true } label: {
                    Label(loc("Subscription"), systemImage: "arrow.down.circle")
                }
                .glassButton()
                Button { showAddSheet = true } label: {
                    Label(loc("Add Link"), systemImage: "plus")
                }
                .glassButton()
                Button {
                    Task { isRefreshing = true; await SubscriptionService.refreshAll(store); isRefreshing = false }
                } label: {
                    if isRefreshing { ProgressView().controlSize(.small) }
                    else { Label(loc("Refresh"), systemImage: "arrow.clockwise") }
                }
                .glassButton()
                .disabled(isRefreshing)

                Button {
                    pinger.test(store.allServers, tunActive: tunActive)
                } label: {
                    Label(loc("Test Ping"), systemImage: "speedometer")
                }
                .glassButton()
                .disabled(store.allServers.isEmpty)

                if hasManualServers {
                    Button {
                        selectionMode.toggle()
                        selectedForDeletion.removeAll()
                    } label: {
                        Label(loc("Select"), systemImage: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .glassButton()
                }

                Spacer()
            }
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    /// Bar shown in multi-select mode: select-all / delete-selected / cancel.
    private var deletionBar: some View {
        // The active server can't be deleted while connected.
        let activeID = connection.isConnected ? connection.activeServerID : nil
        let manualIDs = Set(store.subscriptions.filter(\.isManual)
            .flatMap { $0.servers.map(\.id) })
            .subtracting(activeID.map { [$0] } ?? [])
        let allSelected = !manualIDs.isEmpty && selectedForDeletion == manualIDs
        return HStack(spacing: 12) {
            Button(allSelected ? loc("Deselect All") : loc("Select All")) {
                selectedForDeletion = allSelected ? [] : manualIDs
            }
            .glassButton()
            Text("\(selectedForDeletion.count)")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) {
                // Never delete the active server even if somehow selected.
                store.removeServers(ids: selectedForDeletion.subtracting(activeID.map { [$0] } ?? []))
                selectedForDeletion.removeAll()
                selectionMode = false
            } label: {
                Label(loc("Delete Selected"), systemImage: "trash")
            }
            .glassProminentButton().tint(.red)
            .disabled(selectedForDeletion.isEmpty)
            Button(loc("Cancel")) {
                selectionMode = false
                selectedForDeletion.removeAll()
            }
            .glassButton()
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
    }

    private var statusColor: Color {
        switch connection.state {
        case .connected:  return .green
        case .connecting: return .orange
        case .failed:     return .red
        case .disconnected: return .secondary
        }
    }
}

// MARK: - Subscription group (collapsible)

struct SubscriptionGroupView: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(PingTester.self) private var pinger
    @Environment(Loc.self) private var loc
    let subscription: Subscription
    var searchText: String = ""
    var aliveOnly: Bool = false
    var sortByPing: Bool = false
    var selectionMode: Bool = false
    var selectedForDeletion: Binding<Set<UUID>> = .constant([])

    /// Server whose QR code is currently being shown (drives the QR sheet).
    @State private var qrServer: ProxyConfig?

    /// Servers after applying search text, alive filter, and ping sort.
    private var visibleServers: [ProxyConfig] {
        ServersPane.filterServers(subscription.servers, search: searchText,
                                  aliveOnly: aliveOnly, sortByPing: sortByPing,
                                  pinger: pinger)
    }

    /// Hide groups entirely filtered out by an active search/alive filter.
    private var isHidden: Bool {
        (!searchText.isEmpty || aliveOnly) && visibleServers.isEmpty
    }

    var body: some View {
        if isHidden {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                groupHeader
                if !subscription.isCollapsed {
                    ForEach(visibleServers) { server in
                        let isActive = connection.activeServerID == server.id
                        let isLocked = isActive && connection.isConnected
                        HStack(spacing: 8) {
                            if selectionMode {
                                Image(systemName: isLocked ? "lock.fill"
                                      : (selectedForDeletion.wrappedValue.contains(server.id)
                                         ? "checkmark.circle.fill" : "circle"))
                                    .foregroundStyle(isLocked ? .secondary
                                                     : (selectedForDeletion.wrappedValue.contains(server.id)
                                                        ? Color.accentColor : .secondary))
                                    .padding(.leading, 14)
                            }
                            ServerRow(
                                server: server,
                                isSelected: store.selectedServerID == server.id,
                                isActive: isActive,
                                latency: pinger.latency(for: server.id),
                                isTesting: pinger.isTesting(server.id)
                            )
                        }
                        .contentShape(Rectangle())
                        .id(server.id)
                        .onTapGesture {
                            if selectionMode {
                                if !isLocked { toggleSelection(server.id) }
                            } else { handleTap(server) }
                        }
                        .contextMenu {
                            Button(connection.isConnected ? loc("Switch here") : loc("Connect")) {
                                store.select(server.id); connection.connect(to: server)
                            }
                            Button(loc("Test ping")) { pinger.test([server], tunActive: connection.mode == .tun && connection.isConnected) }
                            Divider()
                            Button(loc("Copy link")) {
                                let link = LinkBuilder.link(for: server)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(link, forType: .string)
                            }
                            Button(loc("Show QR code")) { qrServer = server }
                            if subscription.isManual && !isLocked {
                                Divider()
                                Button(loc("Delete"), role: .destructive) {
                                    store.removeServer(id: server.id)
                                }
                            }
                        }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
            .sheet(item: $qrServer) { server in
                QRDisplaySheet(server: server)
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedForDeletion.wrappedValue.contains(id) {
            selectedForDeletion.wrappedValue.remove(id)
        } else {
            selectedForDeletion.wrappedValue.insert(id)
        }
    }

    /// Disconnected: tap = select only. Connected: tap = switch immediately.
    private func handleTap(_ server: ProxyConfig) {
        store.select(server.id)
        if connection.isConnected {
            connection.connect(to: server)
        }
    }

    private var groupHeader: some View {
        HStack(spacing: 10) {
            // Larger chevron hit target with its own background.
            Button {
                store.toggleCollapsed(id: subscription.id)
            } label: {
                Image(systemName: subscription.isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(subscription.name).font(.headline)
                    Text("\(subscription.servers.count)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                if let note = subscription.note, !note.isEmpty {
                    Text(note)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                trafficLine
            }
            Spacer()
            Menu {
                Button("Test ping (group)") { pinger.test(subscription.servers, tunActive: connection.mode == .tun && connection.isConnected) }
                if !subscription.isManual {
                    Divider()
                    Button("Refresh now") {
                        Task { await SubscriptionService.refresh(subscription, into: store) }
                    }
                    Toggle("Auto-update", isOn: Binding(
                        get: { subscription.autoUpdate },
                        set: { store.setAutoUpdate($0, id: subscription.id) }
                    ))
                    Divider()
                    // Can't remove a subscription that holds the active server.
                    let holdsActive = connection.isConnected
                        && subscription.servers.contains { $0.id == connection.activeServerID }
                    Button("Remove", role: .destructive) {
                        store.removeSubscription(id: subscription.id)
                    }
                    .disabled(holdsActive)
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 16))
            }
            .menuStyle(.borderlessButton).fixedSize().frame(width: 28)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { store.toggleCollapsed(id: subscription.id) }
    }

    @ViewBuilder
    private var trafficLine: some View {
        if let used = subscription.usedBytes, let total = subscription.totalBytes {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(ByteFormat.string(used)) / \(ByteFormat.string(total))")
                    if let exp = subscription.expiresAt {
                        Text("· until \(exp.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
                if let frac = subscription.usageFraction {
                    ProgressView(value: frac)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 220)
                        .tint(frac > 0.9 ? .red : .accentColor)
                }
            }
        } else if let exp = subscription.expiresAt {
            Text("Expires \(exp.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Server row

struct ServerRow: View {
    let server: ProxyConfig
    let isSelected: Bool
    let isActive: Bool
    let latency: Int??     // outer nil = untested; inner nil = unreachable
    let isTesting: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isActive ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 7, height: 7)
            Text(server.name).lineLimit(1)
            Spacer()
            latencyBadge
            Text(server.proto.rawValue.uppercased())
                .font(.caption2).foregroundStyle(.secondary)
            if isActive {
                Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .padding(.leading, 18)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    @ViewBuilder
    private var latencyBadge: some View {
        if isTesting {
            ProgressView().controlSize(.mini)
        } else if let outer = latency {
            if let ms = outer {
                Text("\(ms) ms")
                    .font(.caption2).monospacedDigit()
                    .foregroundStyle(latencyColor(ms))
            } else {
                Text("timeout")
                    .font(.caption2).foregroundStyle(.red)
            }
        }
    }

    private func latencyColor(_ ms: Int) -> Color {
        switch ms {
        case ..<150:  return .green
        case ..<350:  return .orange
        default:      return .red
        }
    }
}

// MARK: - Compact log pane

struct LogPane: View {
    let text: String
    var onClear: (() -> Void)? = nil

    private var lineCount: Int {
        text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header toolbar.
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Logs")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(lineCount)")
                    .font(.system(size: 10, weight: .medium)).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Copy all logs")
                .disabled(text.isEmpty)
                Button {
                    onClear?()
                } label: {
                    Image(systemName: "trash").font(.system(size: 11))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Clear logs")
                .disabled(text.isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .logHeaderBackground()

            Divider().opacity(0.5)

            // Scrollable monospaced body.
            ScrollViewReader { proxy in
                ScrollView {
                    Text(text.isEmpty ? "No logs yet." : text)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(text.isEmpty ? Color.secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                        .id("bottom")
                }
                .onChange(of: text) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .logPaneBackground()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

// MARK: - Log pane (sidebar destination)

/// Full-height Log destination hosting the existing log view. (Restyled with
/// level tags / filter in a later step.)
struct LogDetailPane: View {
    @Environment(ConnectionManager.self) private var connection
    @Environment(Loc.self) private var loc

    var body: some View {
        LogPane(text: connection.logs, onClear: { connection.clearLogs() })
            .navigationTitle(loc("Log"))
    }
}

extension View {
    /// Glass material behind the log panel on macOS 26+, with a solid
    /// text-background fallback on earlier systems.
    @ViewBuilder
    func logPaneBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.background(.regularMaterial)
        } else {
            self.background(Color(nsColor: .textBackgroundColor))
        }
    }

    /// Slightly tinted header strip so the toolbar reads above the body.
    @ViewBuilder
    func logHeaderBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.background(.thinMaterial)
        } else {
            self.background(Color.primary.opacity(0.05))
        }
    }
}

// MARK: - Liquid Glass styling (macOS 26+) with graceful fallback

extension View {
    /// Applies the Liquid Glass button style on macOS 26+, falling back to the
    /// bordered style on earlier releases so the app still builds and runs on
    /// the .macOS(.v14) deployment target.
    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Prominent Liquid Glass variant for primary actions (e.g. Connect).
    @ViewBuilder
    func glassProminentButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Liquid Glass toggle (a button-style toggle that picks up the glass
    /// material when selected on macOS 26+), with a bordered-button fallback.
    @ViewBuilder
    func glassToggle() -> some View {
        if #available(macOS 26.0, *) {
            self.toggleStyle(.button).buttonStyle(.glass)
        } else {
            self.toggleStyle(.button)
        }
    }
}

// MARK: - Draggable Liquid Glass mode switch (Proxy / TUN)

/// A two-position switch styled with Liquid Glass. The glass thumb can be
/// tapped on either side or grabbed and dragged across to flip between System
/// Proxy and TUN. Falls back to a plain segmented look on pre-macOS 26.
private struct ModeGlassSwitch: View {
    @Binding var mode: TunnelMode
    var isDisabled: Bool
    var onChange: (TunnelMode) -> Void

    /// Live horizontal offset of the thumb while dragging (nil = snapped).
    @State private var dragX: CGFloat? = nil

    private let labels: [(TunnelMode, String)] = [
        (.systemProxy, "Proxy"), (.tun, "TUN"),
    ]
    private let height: CGFloat = 28
    private let segWidth: CGFloat = 66

    private var trackWidth: CGFloat { segWidth * 2 }
    private var selectedIndex: Int { mode == .systemProxy ? 0 : 1 }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track.
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.08))

            // Sliding glass thumb.
            thumb
                .frame(width: segWidth, height: height - 4)
                .offset(x: thumbOffset + 2)
                .animation(dragX == nil ? .spring(response: 0.28, dampingFraction: 0.8) : nil,
                           value: selectedIndex)

            // Labels on top.
            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { idx, item in
                    Text(item.1)
                        .font(.system(size: 12, weight: idx == selectedIndex ? .semibold : .regular))
                        .foregroundStyle(idx == selectedIndex ? Color.primary : .secondary)
                        .frame(width: segWidth, height: height)
                        .contentShape(Rectangle())
                        .onTapGesture { select(labels[idx].0) }
                }
            }
        }
        .frame(width: trackWidth, height: height)
        .clipShape(Capsule(style: .continuous))
        .opacity(isDisabled ? 0.5 : 1)
        .allowsHitTesting(!isDisabled)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { v in
                    // Centre the thumb under the finger, clamped to the track.
                    let half = segWidth / 2
                    dragX = min(max(v.location.x - half, 0), trackWidth - segWidth)
                }
                .onEnded { v in
                    let target: TunnelMode = v.location.x > trackWidth / 2 ? .tun : .systemProxy
                    dragX = nil
                    select(target)
                }
        )
    }

    /// Where the thumb sits: follows the finger mid-drag, else snaps to segment.
    private var thumbOffset: CGFloat {
        if let dragX { return dragX }
        return CGFloat(selectedIndex) * segWidth
    }

    @ViewBuilder
    private var thumb: some View {
        if #available(macOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        } else {
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
    }

    private func select(_ newMode: TunnelMode) {
        guard newMode != mode else { return }
        mode = newMode
        onChange(newMode)
    }
}
