import Foundation

/// Serializes a `ProxyConfig` back into a share link (the inverse of
/// `LinkParser`). Used for "Copy link" and QR-code export. Round-trips the
/// fields the app understands; provider-specific extras may not survive.
enum LinkBuilder {

    static func link(for cfg: ProxyConfig) -> String {
        switch cfg.proto {
        case .vless:       return vlessLink(cfg)
        case .vmess:       return vmessLink(cfg)
        case .trojan:      return trojanLink(cfg)
        case .shadowsocks: return ssLink(cfg)
        case .hysteria2:   return hysteria2Link(cfg)
        case .tuic:        return tuicLink(cfg)
        case .anytls:      return anytlsLink(cfg)
        case .wireguard:   return wireguardLink(cfg)
        }
    }

    // MARK: - Builders

    private static func vlessLink(_ cfg: ProxyConfig) -> String {
        var q: [String: String] = ["encryption": cfg.encryption ?? "none",
                                    "type": cfg.network.rawValue]
        if let flow = cfg.flow, !flow.isEmpty { q["flow"] = flow }
        applyStreamQuery(&q, cfg)
        return assemble(scheme: "vless", user: cfg.uuid, host: cfg.address,
                        port: cfg.port, query: q, name: cfg.name)
    }

    private static func vmessLink(_ cfg: ProxyConfig) -> String {
        // vmess uses a base64-encoded JSON payload.
        var json: [String: Any] = [
            "v": "2",
            "ps": cfg.name,
            "add": cfg.address,
            "port": String(cfg.port),
            "id": cfg.uuid ?? "",
            "aid": String(cfg.alterId ?? 0),
            "net": cfg.network.rawValue,
            "type": "none",
            "tls": cfg.security == .none ? "" : cfg.security.rawValue
        ]
        if let host = cfg.host { json["host"] = host }
        if let path = cfg.path { json["path"] = path }
        if let sni = cfg.sni { json["sni"] = sni }
        if let alpn = cfg.alpn { json["alpn"] = alpn.joined(separator: ",") }
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            return "vmess://"
        }
        return "vmess://\(data.base64EncodedString())"
    }

    private static func trojanLink(_ cfg: ProxyConfig) -> String {
        var q: [String: String] = ["type": cfg.network.rawValue]
        applyStreamQuery(&q, cfg)
        return assemble(scheme: "trojan", user: cfg.password, host: cfg.address,
                        port: cfg.port, query: q, name: cfg.name)
    }

    private static func ssLink(_ cfg: ProxyConfig) -> String {
        // SIP002: ss://base64(method:password)@host:port#name
        let userinfo = "\(cfg.method ?? "aes-256-gcm"):\(cfg.password ?? "")"
        let b64 = Data(userinfo.utf8).base64EncodedString()
        let frag = fragment(cfg.name)
        return "ss://\(b64)@\(cfg.address):\(cfg.port)\(frag)"
    }

    private static func hysteria2Link(_ cfg: ProxyConfig) -> String {
        var q: [String: String] = [:]
        if let sni = cfg.sni { q["sni"] = sni }
        if cfg.allowInsecure { q["insecure"] = "1" }
        if let alpn = cfg.alpn { q["alpn"] = alpn.joined(separator: ",") }
        if let obfs = cfg.obfs { q["obfs"] = obfs }
        if let op = cfg.obfsPassword { q["obfs-password"] = op }
        return assemble(scheme: "hysteria2", user: cfg.password, host: cfg.address,
                        port: cfg.port, query: q, name: cfg.name)
    }

    private static func tuicLink(_ cfg: ProxyConfig) -> String {
        var q: [String: String] = [:]
        if let sni = cfg.sni { q["sni"] = sni }
        if cfg.allowInsecure { q["allow_insecure"] = "1" }
        if let alpn = cfg.alpn { q["alpn"] = alpn.joined(separator: ",") }
        if let cc = cfg.congestionControl { q["congestion_control"] = cc }
        if let urm = cfg.udpRelayMode { q["udp_relay_mode"] = urm }
        // userinfo = uuid:password — pass as separate components so the colon
        // separator survives (URLComponents encodes each part independently).
        return assemble(scheme: "tuic", user: cfg.uuid, password: cfg.password,
                        host: cfg.address, port: cfg.port, query: q, name: cfg.name)
    }

    private static func anytlsLink(_ cfg: ProxyConfig) -> String {
        var q: [String: String] = [:]
        if let sni = cfg.sni { q["sni"] = sni }
        if cfg.allowInsecure { q["insecure"] = "1" }
        if let alpn = cfg.alpn { q["alpn"] = alpn.joined(separator: ",") }
        return assemble(scheme: "anytls", user: cfg.password, host: cfg.address,
                        port: cfg.port, query: q, name: cfg.name)
    }

    private static func wireguardLink(_ cfg: ProxyConfig) -> String {
        var q: [String: String] = [:]
        if let pub = cfg.peerPublicKey { q["publickey"] = pub }
        if let addr = cfg.localAddresses { q["address"] = addr.joined(separator: ",") }
        if let psk = cfg.presharedKey { q["presharedkey"] = psk }
        if let mtu = cfg.mtu { q["mtu"] = String(mtu) }
        if let r = cfg.reserved { q["reserved"] = r.map(String.init).joined(separator: ",") }
        return assemble(scheme: "wireguard", user: cfg.privateKey, host: cfg.address,
                        port: cfg.port, query: q, name: cfg.name)
    }

    // MARK: - Shared

    private static func applyStreamQuery(_ q: inout [String: String], _ cfg: ProxyConfig) {
        if cfg.security != .none { q["security"] = cfg.security.rawValue }
        if let sni = cfg.sni, !sni.isEmpty { q["sni"] = sni }
        if let fp = cfg.fingerprint, !fp.isEmpty { q["fp"] = fp }
        if let alpn = cfg.alpn, !alpn.isEmpty { q["alpn"] = alpn.joined(separator: ",") }
        if let pbk = cfg.publicKey, !pbk.isEmpty { q["pbk"] = pbk }
        if let sid = cfg.shortId, !sid.isEmpty { q["sid"] = sid }
        if let spx = cfg.spiderX, !spx.isEmpty { q["spx"] = spx }
        if let host = cfg.host, !host.isEmpty { q["host"] = host }
        if let path = cfg.path, !path.isEmpty { q["path"] = path }
        if let sn = cfg.serviceName, !sn.isEmpty { q["serviceName"] = sn }
        if cfg.network == .xhttp, let mode = cfg.xhttpMode { q["mode"] = mode }
        if let pad = cfg.xPaddingBytes, !pad.isEmpty { q["x_padding_bytes"] = pad }
        if cfg.allowInsecure { q["allowInsecure"] = "1" }
    }

    /// Builds `scheme://user[:password]@host:port?query#name` with escaping.
    private static func assemble(scheme: String, user: String?, password: String? = nil,
                                 host: String, port: Int,
                                 query: [String: String], name: String) -> String {
        var comps = URLComponents()
        comps.scheme = scheme
        comps.host = host
        comps.port = port
        if let user, !user.isEmpty {
            comps.user = user
            if let password, !password.isEmpty { comps.password = password }
        }
        if !query.isEmpty {
            comps.queryItems = query.sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var s = comps.string ?? "\(scheme)://\(host):\(port)"
        s += fragment(name)
        return s
    }

    private static func fragment(_ name: String) -> String {
        guard !name.isEmpty,
              let enc = name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
            return ""
        }
        return "#\(enc)"
    }
}
