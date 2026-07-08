import SwiftUI

// MARK: - Window shell

/// Top-level window shell: a native split view with a translucent sidebar
/// (Servers / Log / Settings) and the selected pane in the detail column.
/// Traffic-light buttons float over the sidebar and the sidebar toggle lives in
/// the toolbar, matching the redesign's macOS-native structure.
struct ContentView: View {
    @Environment(ServerStore.self) private var store
    @Environment(Loc.self) private var loc
    @AppStorage("sidebarSelection") private var selectionRaw = SidebarItem.servers.rawValue
    @AppStorage("sidebarCollapsed") private var isSidebarCollapsed = false
    /// Whether the Servers pane's inline search field is shown (toggled from
    /// the titlebar search button, so the state lives up here).
    @State private var searchVisible = false

    /// Width of the sidebar column; the hairline separator sits at its edge.
    static let sidebarWidth: CGFloat = 220

    /// Current on-screen width of the sidebar column.
    private var sidebarCurrentWidth: CGFloat {
        isSidebarCollapsed ? 0 : Self.sidebarWidth
    }

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
        ZStack(alignment: .topLeading) {
            VisualEffectBackground(material: .sidebar)
                .ignoresSafeArea()

            // Subtle opaque wash so the desktop shows through a little less
            // than the raw sidebar material allows.
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.35)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // The sidebar keeps its intrinsic width and slides out to the
                // left when collapsed; the outer frame clips it away.
                Sidebar(selection: selection)
                    .frame(width: Self.sidebarWidth)
                    .frame(width: sidebarCurrentWidth, alignment: .trailing)
                    .clipped()

                detailColumn
            }
            // Span the transparent titlebar too: the sidebar lays out its own
            // top strip so the add button can sit level with the traffic
            // lights, Reeder-style.
            .ignoresSafeArea()
        }
        .background(WindowConfigurator())
        .overlay(alignment: .leading) {
            // Hairline sits at the sidebar's right edge (sidebar is flush to
            // the window's left, so its width is the full sidebarWidth).
            HStack(spacing: 0) {
                Color.clear.frame(width: sidebarCurrentWidth)
                Color(nsColor: .separatorColor).frame(width: 1)
            }
            .opacity(isSidebarCollapsed ? 0 : 1)
            .ignoresSafeArea()
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isSidebarCollapsed)
    }

    /// Detail column: the floating pill header (sidebar toggle + page title)
    /// on the titlebar strip, then the selected pane below.
    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                DetailHeaderPill(
                    title: loc(selection.wrappedValue.title),
                    isSidebarCollapsed: $isSidebarCollapsed
                )
                Spacer()
                if selection.wrappedValue == .servers {
                    ServersTitleBarControls(searchVisible: $searchVisible)
                }
            }
            // Clear the traffic lights when they float over this column.
            .padding(.leading, isSidebarCollapsed ? 104 : 16)
            .padding(.trailing, 16)
            .frame(height: 52)

            Group {
                switch selection.wrappedValue {
                case .servers:  ServersPane(searchVisible: $searchVisible)
                case .log:      LogDetailPane()
                case .settings: SettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Floating Liquid Glass capsule at the top of the detail column: a sidebar
/// toggle, a hairline divider, and the current page's name — Reeder-style.
private struct DetailHeaderPill: View {
    let title: String
    @Binding var isSidebarCollapsed: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                isSidebarCollapsed.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Hide or show the sidebar")

            Divider()
                .frame(height: 16)

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .padding(.leading, 10)
                .padding(.trailing, 14)
        }
        .frame(height: 34)
        .glassPill()
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

/// Reeder-style sidebar drawn directly on the shared window material: a
/// prominent two-line Servers item up top (bold title, small subtitle, tinted
/// icon) followed by plain rows. The selected row sits on a Liquid Glass slab;
/// hover is a faint quaternary wash. The column lays out its own titlebar
/// strip so the circular add button lines up with the traffic lights.
struct Sidebar: View {
    @Environment(ServerStore.self) private var store
    @Environment(Loc.self) private var loc
    @Binding var selection: SidebarItem

    @State private var showAddSheet = false

    /// Height of the transparent titlebar region (traffic lights + add button).
    private let titleBarHeight: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    SidebarRow(
                        item: .servers,
                        title: loc("Servers"),
                        subtitle: loc("All servers"),
                        count: store.allServers.count,
                        isSelected: selection == .servers
                    ) { selection = .servers }

                    SidebarRow(
                        item: .log,
                        title: loc("Log"),
                        isSelected: selection == .log
                    ) { selection = .log }

                    SidebarRow(
                        item: .settings,
                        title: loc("Settings"),
                        isSelected: selection == .settings
                    ) { selection = .settings }
                }
                .padding(.top, 24)
                .padding(.leading, 14)
                .padding(.trailing, 10)
            }
        }
        .sheet(isPresented: $showAddSheet) { AddServerSheet() }
    }

    private var titleBar: some View {
        Color.clear.frame(height: titleBarHeight)
    }
}

/// One sidebar destination row. With a subtitle it renders as the prominent
/// two-line item (large bold title, accent icon); without one, as a plain row.
private struct SidebarRow: View {
    let item: SidebarItem
    let title: String
    var subtitle: String? = nil
    /// Optional trailing count badge (e.g. total servers).
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    private var isProminent: Bool { subtitle != nil }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .font(.system(size: isProminent ? 18 : 15, weight: .medium))
                    .foregroundStyle(isProminent
                                     ? AnyShapeStyle(DS.accent)
                                     : AnyShapeStyle(.secondary))
                    .frame(width: 24)
                if let subtitle {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(title)
                        .font(.system(size: 15))
                }
                Spacer(minLength: 0)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, isProminent ? 8 : 9)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .background { rowBackground }
        .onHover { isHovering = $0 }
        // Ease the selection slab and hover wash in and out rather than
        // snapping, so clicking a row feels like a gentle fade.
        .animation(.easeInOut(duration: 0.3), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: isHovering)
    }

    /// Selected rows get the Liquid Glass slab (quaternary fill pre-macOS 26);
    /// hovered rows a faint wash so the pointer state reads without weight.
    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: shape)
            } else {
                shape.fill(.quaternary)
            }
        } else if isHovering {
            shape.fill(.quaternary.opacity(0.5))
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

    /// Circular Liquid Glass button (toolbar-style icon buttons, e.g. the
    /// sidebar's add button), with a bordered-circle fallback.
    @ViewBuilder
    func glassCircleButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass).buttonBorderShape(.circle)
        } else {
            self.buttonStyle(.bordered).buttonBorderShape(.circle)
        }
    }

    /// Floating Liquid Glass capsule surface (the detail header pill). Uses
    /// the clear glass variant so the pill stays light and airy, with a
    /// quaternary-fill capsule fallback on earlier systems.
    @ViewBuilder
    func glassPill() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(
                .clear.tint(.black.opacity(0.14)).interactive(),
                in: Capsule(style: .continuous)
            )
        } else {
            self.background(Capsule(style: .continuous).fill(.quaternary.opacity(0.8)))
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
