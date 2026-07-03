import Foundation

/// How traffic is captured.
enum TunnelMode: String, Codable, CaseIterable, Identifiable {
    case systemProxy   // SOCKS/HTTP system proxy (no admin, browsers only)
    case tun           // full-traffic TUN via tun2socks (needs admin)

    var id: String { rawValue }
    var title: String {
        switch self {
        case .systemProxy: return "System Proxy"
        case .tun:         return "TUN (All Apps)"
        }
    }
    var subtitle: String {
        switch self {
        case .systemProxy: return "Browsers & proxy-aware apps. No password needed."
        case .tun:         return "All traffic incl. Telegram, terminal, games. Asks for password."
        }
    }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

/// Verbosity of the bundled Xray core's log output.
enum LogLevel: String, Codable, CaseIterable, Identifiable {
    case debug, info, warning, error, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .debug:   return "Debug"
        case .info:    return "Info"
        case .warning: return "Warning"
        case .error:   return "Error"
        case .none:    return "None"
        }
    }
}


/// User-facing settings, persisted alongside subscriptions.
struct AppSettings: Codable, Equatable {
    var mode: TunnelMode = .systemProxy
    var appearance: AppAppearance = .system
    var language: AppLanguage = .system
    var autoUpdateSubscriptions: Bool = true
    var autoUpdateIntervalHours: Int = 12
    var closeToTray: Bool = true            // red button hides to menu bar
    var socksPort: Int = 10808
    var httpPort: Int = 10809
    var lastSelectedServerID: UUID?
    var logLevel: LogLevel = .warning

    // Routing
    var routingPreset: RoutingPreset = .bypassLAN
    var customRules: [RoutingRule] = []
    var blockAds: Bool = false
    var geoSource: GeoAssetSource = .loyalsoldier
    var customGeoipURL: String = ""
    var customGeositeURL: String = ""

    // Startup
    var autoConnectOnLaunch: Bool = false
    var launchAtLogin: Bool = false

    // Notifications
    var notifyOnConnect: Bool = false

    // Subscription
    var sendHwid: Bool = true

    init() {}

    /// Resilient decoding: any missing key falls back to its default so old
    /// `store.json` files (with fewer/older fields) still load cleanly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? fallback
        }
        mode = get(.mode, .systemProxy)
        appearance = get(.appearance, .system)
        language = get(.language, .system)
        autoUpdateSubscriptions = get(.autoUpdateSubscriptions, true)
        autoUpdateIntervalHours = get(.autoUpdateIntervalHours, 12)
        closeToTray = get(.closeToTray, true)
        socksPort = get(.socksPort, 10808)
        httpPort = get(.httpPort, 10809)
        lastSelectedServerID = try? c.decode(UUID.self, forKey: .lastSelectedServerID)
        logLevel = get(.logLevel, .warning)
        routingPreset = get(.routingPreset, .bypassLAN)
        customRules = get(.customRules, [])
        blockAds = get(.blockAds, false)
        geoSource = get(.geoSource, .loyalsoldier)
        customGeoipURL = get(.customGeoipURL, "")
        customGeositeURL = get(.customGeositeURL, "")
        autoConnectOnLaunch = get(.autoConnectOnLaunch, false)
        launchAtLogin = get(.launchAtLogin, false)
        notifyOnConnect = get(.notifyOnConnect, false)
        sendHwid = get(.sendHwid, true)
    }

    /// The ordered routing rules to feed Xray, derived from the active preset
    /// (or the user's custom list).
    var effectiveRoutingRules: [RoutingRule] {
        if routingPreset == .custom {
            var rules: [RoutingRule] = []
            if blockAds {
                rules.append(RoutingRule(name: "Block ads", outbound: .block,
                                         domains: ["geosite:category-ads-all"]))
            }
            rules.append(contentsOf: customRules)
            return rules
        }
        return routingPreset.builtInRules(blockAds: blockAds)
    }
}

