import Foundation

/// Where a matched rule sends its traffic.
enum RuleOutbound: String, Codable, CaseIterable, Identifiable {
    case proxy    // through the selected server
    case direct   // straight to the internet (bypass proxy)
    case block    // blackhole (drop)

    var id: String { rawValue }
    var tag: String { rawValue }
    var title: String {
        switch self {
        case .proxy:  return "Proxy"
        case .direct: return "Direct"
        case .block:  return "Block"
        }
    }
}

/// A single routing rule. Matchers are newline/comma free arrays. A rule
/// matches if ANY of its domain/ip entries match (Xray "field" rule semantics).
///
/// Entries support Xray's matcher syntax directly:
///   - domains: `example.com`, `domain:example.com`, `geosite:category-ads-all`,
///     `regexp:.*\.example\.com`, `keyword:google`
///   - ips:     `1.2.3.0/24`, `geoip:cn`, `geoip:private`
struct RoutingRule: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var outbound: RuleOutbound = .proxy
    var domains: [String] = []
    var ips: [String] = []
    var port: String = ""          // e.g. "443" or "1000-2000" (optional)
    var enabled: Bool = true

    /// Renders to an Xray routing "field" rule, or nil if it has no matchers.
    func xrayRule() -> [String: Any]? {
        guard enabled else { return nil }
        var dict: [String: Any] = ["type": "field", "outboundTag": outbound.tag]
        var hasMatcher = false
        if !domains.isEmpty { dict["domain"] = domains; hasMatcher = true }
        if !ips.isEmpty { dict["ip"] = ips; hasMatcher = true }
        let trimmedPort = port.trimmingCharacters(in: .whitespaces)
        if !trimmedPort.isEmpty { dict["port"] = trimmedPort; hasMatcher = true }
        return hasMatcher ? dict : nil
    }
}

/// Built-in routing presets, mirroring v2rayN/Nekoray. Each produces an ordered
/// rule list. Presets that reference `geosite:`/`geoip:` need the geo .dat files.
enum RoutingPreset: String, Codable, CaseIterable, Identifiable {
    case global         // everything via proxy
    case bypassLAN      // proxy all, LAN/private direct
    case bypassChina    // China sites + LAN direct, rest proxy
    case bypassRussia   // Russian/gov sites direct, rest proxy (anti-censorship)
    case custom         // user-defined rules

    var id: String { rawValue }

    var title: String {
        switch self {
        case .global:      return "Global"
        case .bypassLAN:   return "Bypass LAN"
        case .bypassChina: return "Bypass China"
        case .bypassRussia: return "Bypass Russia"
        case .custom:      return "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .global:      return "All traffic through the proxy."
        case .bypassLAN:   return "Proxy everything except local/LAN addresses."
        case .bypassChina: return "Mainland China sites & LAN go direct, rest via proxy."
        case .bypassRussia: return "Russian & .ru-gov sites go direct, rest via proxy."
        case .custom:      return "Your own ordered rule list."
        }
    }

    /// Does this preset reference geosite/geoip categories (needs .dat files)?
    var needsGeoAssets: Bool {
        switch self {
        case .bypassChina, .bypassRussia: return true
        case .global, .bypassLAN, .custom: return false
        }
    }

    private static let privateCIDRs = [
        "127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
        "169.254.0.0/16", "::1/128", "fc00::/7", "fe80::/10"
    ]

    /// Builds the ordered rule list for built-in presets. `custom` returns the
    /// user's stored rules instead (handled by the caller).
    func builtInRules(blockAds: Bool) -> [RoutingRule] {
        var rules: [RoutingRule] = []
        if blockAds {
            rules.append(RoutingRule(name: "Block ads",
                                     outbound: .block,
                                     domains: ["geosite:category-ads-all"]))
        }
        switch self {
        case .global:
            break
        case .bypassLAN:
            rules.append(RoutingRule(name: "LAN direct", outbound: .direct,
                                     ips: Self.privateCIDRs))
        case .bypassChina:
            rules.append(RoutingRule(name: "LAN direct", outbound: .direct,
                                     ips: Self.privateCIDRs + ["geoip:private"]))
            rules.append(RoutingRule(name: "China sites direct", outbound: .direct,
                                     domains: ["geosite:cn"]))
            rules.append(RoutingRule(name: "China IPs direct", outbound: .direct,
                                     ips: ["geoip:cn"]))
        case .bypassRussia:
            rules.append(RoutingRule(name: "LAN direct", outbound: .direct,
                                     ips: Self.privateCIDRs + ["geoip:private"]))
            rules.append(RoutingRule(name: "RU gov & category direct", outbound: .direct,
                                     domains: ["geosite:category-gov-ru", "geosite:category-ru"]))
            rules.append(RoutingRule(name: "RU IPs direct", outbound: .direct,
                                     ips: ["geoip:ru"]))
        case .custom:
            break
        }
        return rules
    }
}

/// Source of the geoip.dat / geosite.dat rule databases (GitHub releases).
enum GeoAssetSource: String, Codable, CaseIterable, Identifiable {
    case loyalsoldier   // global + China, ad-blocking
    case runetfreedom   // Russia / anti-censorship
    case v2fly          // official upstream
    case custom         // user-supplied URLs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loyalsoldier: return "Loyalsoldier (global + CN)"
        case .runetfreedom: return "runetfreedom (RU)"
        case .v2fly:        return "v2fly (official)"
        case .custom:       return "Custom URLs"
        }
    }

    /// Download URL for geoip.dat. Uses GitHub release "latest" redirects.
    func geoipURL(custom: String) -> String {
        switch self {
        case .loyalsoldier:
            return "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
        case .runetfreedom:
            return "https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geoip.dat"
        case .v2fly:
            return "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat"
        case .custom:
            return custom
        }
    }

    /// Download URL for geosite.dat.
    func geositeURL(custom: String) -> String {
        switch self {
        case .loyalsoldier:
            return "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
        case .runetfreedom:
            return "https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geosite.dat"
        case .v2fly:
            return "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
        case .custom:
            return ""   // custom geosite entered separately
        }
    }
}
