import Foundation

/// Builds a sing-box JSON configuration from a `ProxyConfig`.
///
/// sing-box is the second core, handling QUIC-based protocols that Xray-core
/// cannot (Hysteria2, TUIC). It exposes the same local SOCKS5 + HTTP inbounds as
/// the Xray builder (on identical ports), so the rest of the app — system proxy,
/// TUN transport, watchdog — is core-agnostic.
enum SingBoxConfigBuilder {

    static func build(for cfg: ProxyConfig,
                      ports: InboundPorts = InboundPorts(),
                      rules: [RoutingRule] = [],
                      logLevel: String = "warning") -> [String: Any] {
        var dict: [String: Any] = [
            "log": ["level": singBoxLevel(logLevel), "timestamp": true],
            "inbounds": inbounds(ports),
            "route": route(rules: rules)
        ]
        // WireGuard is configured as a top-level `endpoint` (sing-box 1.11+),
        // not an outbound. Everything else is a normal outbound tagged "proxy".
        if cfg.proto == .wireguard {
            dict["endpoints"] = [wireguardEndpoint(cfg)]
            dict["outbounds"] = [directOutbound(), blockOutbound()]
        } else {
            dict["outbounds"] = [outbound(cfg), directOutbound(), blockOutbound()]
        }
        return dict
    }

    static func jsonData(for cfg: ProxyConfig,
                         ports: InboundPorts = InboundPorts(),
                         rules: [RoutingRule] = [],
                         logLevel: String = "warning") throws -> Data {
        let dict = build(for: cfg, ports: ports, rules: rules, logLevel: logLevel)
        return try JSONSerialization.data(withJSONObject: dict,
                                          options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Log level mapping

    /// Xray uses debug/info/warning/error/none; sing-box uses
    /// trace/debug/info/warn/error/fatal/panic. Map onto the nearest level.
    private static func singBoxLevel(_ xrayLevel: String) -> String {
        switch xrayLevel {
        case "debug":   return "debug"
        case "info":    return "info"
        case "warning": return "warn"
        case "error":   return "error"
        case "none":    return "fatal"
        default:        return "warn"
        }
    }

    // MARK: - Inbounds (same ports as the Xray builder)

    private static func inbounds(_ p: InboundPorts) -> [[String: Any]] {
        [
            [
                "type": "socks",
                "tag": "socks-in",
                "listen": p.listen,
                "listen_port": p.socks
            ],
            [
                "type": "http",
                "tag": "http-in",
                "listen": p.listen,
                "listen_port": p.http
            ]
        ]
    }

    // MARK: - Outbound dispatch

    private static func outbound(_ cfg: ProxyConfig) -> [String: Any] {
        switch cfg.proto {
        case .hysteria2: return hysteria2Outbound(cfg)
        case .tuic:      return tuicOutbound(cfg)
        case .anytls:    return anytlsOutbound(cfg)
        default:
            // Should never happen — sing-box is only used for QUIC protocols.
            return ["type": "direct", "tag": "proxy"]
        }
    }

    private static func hysteria2Outbound(_ cfg: ProxyConfig) -> [String: Any] {
        var out: [String: Any] = [
            "type": "hysteria2",
            "tag": "proxy",
            "server": cfg.address,
            "server_port": cfg.port,
            "password": cfg.password ?? ""
        ]
        if let up = cfg.upMbps { out["up_mbps"] = up }
        if let down = cfg.downMbps { out["down_mbps"] = down }
        if let obfs = cfg.obfs, !obfs.isEmpty {
            out["obfs"] = [
                "type": obfs,
                "password": cfg.obfsPassword ?? ""
            ]
        }
        out["tls"] = tls(cfg, defaultALPN: ["h3"])
        return out
    }

    private static func tuicOutbound(_ cfg: ProxyConfig) -> [String: Any] {
        var out: [String: Any] = [
            "type": "tuic",
            "tag": "proxy",
            "server": cfg.address,
            "server_port": cfg.port,
            "uuid": cfg.uuid ?? "",
            "password": cfg.password ?? "",
            "congestion_control": cfg.congestionControl ?? "bbr",
            "udp_relay_mode": cfg.udpRelayMode ?? "native"
        ]
        out["tls"] = tls(cfg, defaultALPN: ["h3"])
        return out
    }

    private static func anytlsOutbound(_ cfg: ProxyConfig) -> [String: Any] {
        var out: [String: Any] = [
            "type": "anytls",
            "tag": "proxy",
            "server": cfg.address,
            "server_port": cfg.port,
            "password": cfg.password ?? ""
        ]
        // AnyTLS speaks regular TLS (not QUIC), so default to HTTP/1.1 ALPN.
        out["tls"] = tls(cfg, defaultALPN: ["h2", "http/1.1"])
        return out
    }

    /// WireGuard as a sing-box `endpoint` (1.11+ schema). Returns the endpoint
    /// dict; the caller places it in the top-level `endpoints` array.
    private static func wireguardEndpoint(_ cfg: ProxyConfig) -> [String: Any] {
        var peer: [String: Any] = [
            "address": cfg.address,
            "port": cfg.port,
            "public_key": cfg.peerPublicKey ?? "",
            "allowed_ips": ["0.0.0.0/0", "::/0"]
        ]
        if let psk = cfg.presharedKey, !psk.isEmpty { peer["pre_shared_key"] = psk }
        if let reserved = cfg.reserved, reserved.count == 3 { peer["reserved"] = reserved }

        var ep: [String: Any] = [
            "type": "wireguard",
            "tag": "proxy",
            "address": cfg.localAddresses ?? ["10.0.0.2/32"],
            "private_key": cfg.privateKey ?? "",
            "peers": [peer]
        ]
        if let mtu = cfg.mtu { ep["mtu"] = mtu }
        return ep
    }

    private static func tls(_ cfg: ProxyConfig, defaultALPN: [String]) -> [String: Any] {
        var tls: [String: Any] = ["enabled": true]
        if let sni = cfg.sni, !sni.isEmpty { tls["server_name"] = sni }
        tls["insecure"] = cfg.allowInsecure
        let alpn = (cfg.alpn?.isEmpty == false) ? cfg.alpn! : defaultALPN
        tls["alpn"] = alpn
        // uTLS fingerprint mimicry, when requested by the link.
        if let fp = cfg.fingerprint, !fp.isEmpty {
            tls["utls"] = ["enabled": true, "fingerprint": fp]
        }
        return tls
    }

    // MARK: - Auxiliary outbounds + routing

    private static func directOutbound() -> [String: Any] {
        ["type": "direct", "tag": "direct"]
    }

    private static func blockOutbound() -> [String: Any] {
        ["type": "block", "tag": "block"]
    }

    /// Maps the app's ordered routing rules onto sing-box route rules. The first
    /// matching rule wins; anything unmatched falls through to the proxy.
    private static func route(rules: [RoutingRule]) -> [String: Any] {
        var routeRules: [[String: Any]] = []
        for rule in rules where rule.enabled {
            if let r = singBoxRule(rule) { routeRules.append(r) }
        }
        return [
            "rules": routeRules,
            "final": "proxy",
            "auto_detect_interface": true
        ]
    }

    /// Translates a single `RoutingRule` into a sing-box route rule. Domains and
    /// IPs map onto domain_suffix / ip_cidr / port.
    ///
    /// NOTE: sing-box 1.12 removed the inline `geosite`/`geoip` route fields
    /// (they now require remote `rule_set`s), so `geosite:`/`geoip:` entries are
    /// skipped here. The Bypass-LAN preset still works because it lists explicit
    /// private CIDRs; the China/Russia geo presets only apply their non-geo
    /// matchers when the active server runs on the sing-box core.
    private static func singBoxRule(_ rule: RoutingRule) -> [String: Any]? {
        let outbound: String
        switch rule.outbound {
        case .proxy:  outbound = "proxy"
        case .direct: outbound = "direct"
        case .block:  outbound = "block"
        }

        var r: [String: Any] = ["outbound": outbound]
        var hasMatcher = false

        let suffixes = rule.domains.filter { !$0.hasPrefix("geosite:") }
        if !suffixes.isEmpty { r["domain_suffix"] = suffixes; hasMatcher = true }

        let cidrs = rule.ips.filter { !$0.hasPrefix("geoip:") }
        if !cidrs.isEmpty { r["ip_cidr"] = cidrs; hasMatcher = true }

        let trimmedPort = rule.port.trimmingCharacters(in: .whitespaces)
        if !trimmedPort.isEmpty {
            // sing-box wants integer ports; split comma lists, ignore ranges.
            let ports = trimmedPort.split(separator: ",").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            }
            if !ports.isEmpty { r["port"] = ports; hasMatcher = true }
        }

        return hasMatcher ? r : nil
    }
}
