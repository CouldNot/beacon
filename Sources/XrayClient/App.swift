import SwiftUI
import AppKit

@main
struct XrayClientApp: App {
    @State private var store = ServerStore()
    @State private var connection = ConnectionManager()
    @State private var pinger = PingTester()
    @State private var loc = Loc()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Beacon", id: "main") {
            ContentView()
                .environment(store)
                .environment(connection)
                .environment(pinger)
                .environment(loc)
                .frame(minWidth: 760, minHeight: 520)
                .preferredColorScheme(colorScheme)
                .environment(\.layoutDirection, loc.isRTL ? .rightToLeft : .leftToRight)
                .onAppear {
                    loc.language = store.settings.language
                    connection.mode = store.settings.mode
                    connection.routingRules = store.settings.effectiveRoutingRules
                    connection.logLevel = store.settings.logLevel
                    connection.ports.socks = store.settings.socksPort
                    connection.ports.http = store.settings.httpPort
                    connection.notifyOnConnect = store.settings.notifyOnConnect
                    appDelegate.closeToTray = store.settings.closeToTray
                    appDelegate.connection = connection
                    // Keep the login-item registration in sync with the setting.
                    LoginItem.setEnabled(store.settings.launchAtLogin)
                    if store.settings.notifyOnConnect {
                        NotificationManager.requestAuthorization()
                    }
                    // Recover from a previous crash/force-quit that left the
                    // tunnel routes in place (which kills internet).
                    TunManager.emergencyCleanup()
                    Task { await SubscriptionService.refreshDue(store) }
                    // Auto-download geo .dat files if the active preset needs
                    // them and they're missing (first launch).
                    if store.settings.routingPreset.needsGeoAssets,
                       !GeoAssetManager.shared.hasAssets {
                        Task {
                            await GeoAssetManager.shared.download(
                                source: store.settings.geoSource,
                                customGeoip: store.settings.customGeoipURL,
                                customGeosite: store.settings.customGeositeURL)
                        }
                    }
                    // Auto-connect to the last server on launch, if enabled.
                    if store.settings.autoConnectOnLaunch,
                       let server = store.server(withID: store.selectedServerID) {
                        connection.connect(to: server)
                    }
                }
        }
        .windowResizability(.contentSize)
        // No titlebar chrome at all: the traffic lights float directly over the
        // window's single glass surface (see WindowConfigurator).
        .windowStyle(.hiddenTitleBar)

        // Menu bar control: switch servers / disconnect without opening the window.
        MenuBarExtra {
            MenuBarContent()
                .environment(store)
                .environment(connection)
                .environment(loc)
        } label: {
            Image(systemName: connection.isConnected ? "shield.lefthalf.filled" : "shield.slash")
        }
        .menuBarExtraStyle(.menu)
    }

    private var colorScheme: ColorScheme? {
        switch store.settings.appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Handles "close to tray" and clean shutdown of the tunnel on quit so the
/// network is never left routed through a dead tun2socks.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var closeToTray = true
    weak var connection: ConnectionManager?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in the menu bar when close-to-tray is enabled.
        return !closeToTray
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Always restore routes/proxy on quit, even if the user force-quits the
        // window, so the machine isn't left without internet.
        connection?.disconnect()
        // Belt-and-suspenders: ensure any orphaned tunnel is torn down.
        TunManager.emergencyCleanup()
    }
}
