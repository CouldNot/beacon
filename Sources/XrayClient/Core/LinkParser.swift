import Foundation

enum LinkParseError: Error, LocalizedError {
    case unsupportedScheme(String)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedScheme(let s): return "Unsupported link scheme: \(s)"
        case .malformed(let s): return "Malformed link: \(s)"
        }
    }
}

/// Parses proxy share links into `ProxyConfig`.
///
/// Supported:
///   vless://uuid@host:port?params#name
///   vmess://<base64 json>
///   trojan://password@host:port?params#name
///   ss://<base64 method:password>@host:port#name  (and SIP002 variants)
enum LinkParser {

    static func parse(_ raw: String) throws -> ProxyConfig {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let schemeEnd = line.range(of: "://") else {
            throw LinkParseError.malformed(line)
        }
        let scheme = String(line[line.startIndex..<schemeEnd.lowerBound]).lowercased()

        switch scheme {
        case "vless":            return try parseVLESS(line)
        case "vmess":            return try parseVMess(line)
        case "trojan":           return try parseTrojan(line)
        case "ss":               return try parseShadowsocks(line)
        case "hysteria2", "hy2": return try parseHysteria2(line)
        case "tuic":             return try parseTUIC(line)
        case "anytls":           return try parseAnyTLS(line)
        case "wireguard", "wg":  return try parseWireGuard(line)
        default:                 throw LinkParseError.unsupportedScheme(scheme)
        }
    }

    /// Parse many links separated by newlines, skipping any that fail.
    static func parseMany(_ text: String) -> [ProxyConfig] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            try? parse(String(line))
        }
    }

    // MARK: - VLESS

    private static func parseVLESS(_ line: String) throws -> ProxyConfig {
        guard let comps = URLComponents(string: line),
              let uuid = comps.user,
              let host = comps.host,
              let port = comps.port else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: fragmentName(comps) ?? host,
                              proto: .vless, address: host, port: port)
        cfg.uuid = uuid
        let q = queryDict(comps)
        cfg.encryption = q["encryption"] ?? "none"
        cfg.flow = q["flow"]
        applyTransport(&cfg, query: q)
        applySecurity(&cfg, query: q)
        return cfg
    }

    // MARK: - VMess (base64-encoded JSON payload)

    private static func parseVMess(_ line: String) throws -> ProxyConfig {
        let b64 = String(line.dropFirst("vmess://".count))
        guard let data = decodeBase64(b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinkParseError.malformed(line)
        }
        func str(_ k: String) -> String? {
            if let s = json[k] as? String { return s }
            if let n = json[k] as? NSNumber { return n.stringValue }
            return nil
        }
        guard let host = str("add"),
              let portStr = str("port"), let port = Int(portStr),
              let id = str("id") else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: str("ps") ?? host,
                              proto: .vmess, address: host, port: port)
        cfg.uuid = id
        cfg.alterId = Int(str("aid") ?? "0")
        cfg.network = TransportNetwork(rawValue: str("net") ?? "tcp") ?? .tcp
        cfg.path = str("path")
        cfg.host = str("host")
        cfg.serviceName = str("path") // grpc uses path field for serviceName in vmess links
        let tls = (str("tls") ?? "").lowercased()
        cfg.security = tls.contains("reality") ? .reality : (tls == "tls" ? .tls : .none)
        cfg.sni = str("sni") ?? str("host")
        if let alpn = str("alpn") { cfg.alpn = alpn.split(separator: ",").map(String.init) }
        return cfg
    }

    // MARK: - Trojan

    private static func parseTrojan(_ line: String) throws -> ProxyConfig {
        guard let comps = URLComponents(string: line),
              let pwd = comps.user,
              let host = comps.host,
              let port = comps.port else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: fragmentName(comps) ?? host,
                              proto: .trojan, address: host, port: port)
        cfg.password = pwd.removingPercentEncoding ?? pwd
        let q = queryDict(comps)
        applyTransport(&cfg, query: q)
        // Trojan defaults to TLS unless explicitly told otherwise.
        if q["security"] == nil { cfg.security = .tls }
        applySecurity(&cfg, query: q)
        return cfg
    }

    // MARK: - Shadowsocks (SIP002 + legacy base64)

    private static func parseShadowsocks(_ line: String) throws -> ProxyConfig {
        let name = URLComponents(string: line).flatMap(fragmentName)
        // Strip scheme and fragment.
        var body = String(line.dropFirst("ss://".count))
        if let hash = body.firstIndex(of: "#") { body = String(body[body.startIndex..<hash]) }

        var method: String?
        var password: String?
        var host: String?
        var port: Int?

        if let atIdx = body.firstIndex(of: "@") {
            // SIP002: ss://base64(method:pass)@host:port  OR  ss://method:pass@host:port
            let userInfo = String(body[body.startIndex..<atIdx])
            let hostPart = String(body[body.index(after: atIdx)...])
            let decodedUserInfo = decodeBase64(userInfo).flatMap { String(data: $0, encoding: .utf8) } ?? userInfo
            let mp = decodedUserInfo.split(separator: ":", maxSplits: 1).map(String.init)
            if mp.count == 2 { method = mp[0]; password = mp[1] }
            (host, port) = splitHostPort(hostPart)
        } else {
            // Legacy: ss://base64(method:pass@host:port)
            guard let data = decodeBase64(body),
                  let decoded = String(data: data, encoding: .utf8),
                  let atIdx = decoded.firstIndex(of: "@") else {
                throw LinkParseError.malformed(line)
            }
            let userInfo = String(decoded[decoded.startIndex..<atIdx])
            let hostPart = String(decoded[decoded.index(after: atIdx)...])
            let mp = userInfo.split(separator: ":", maxSplits: 1).map(String.init)
            if mp.count == 2 { method = mp[0]; password = mp[1] }
            (host, port) = splitHostPort(hostPart)
        }

        guard let h = host, let p = port, let m = method, let pw = password else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: name ?? h, proto: .shadowsocks, address: h, port: p)
        cfg.method = m
        cfg.password = pw
        return cfg
    }

    // MARK: - Hysteria2 (sing-box core)
    //
    // hysteria2://password@host:port?sni=...&obfs=salamander&obfs-password=...
    //   &insecure=1&alpn=h3#name   (hy2:// is an accepted alias)

    private static func parseHysteria2(_ line: String) throws -> ProxyConfig {
        guard let comps = URLComponents(string: line),
              let host = comps.host,
              let port = comps.port else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: fragmentName(comps) ?? host,
                              proto: .hysteria2, address: host, port: port)
        // The userinfo carries the auth password (may be percent-encoded).
        if let user = comps.user {
            cfg.password = user.removingPercentEncoding ?? user
        }
        let q = queryDict(comps)
        cfg.security = .tls
        cfg.sni = q["sni"] ?? q["peer"]
        cfg.allowInsecure = (q["insecure"] == "1" || q["insecure"] == "true")
        if let alpn = q["alpn"]?.removingPercentEncoding {
            cfg.alpn = alpn.split(separator: ",").map(String.init)
        }
        cfg.obfs = q["obfs"]
        cfg.obfsPassword = (q["obfs-password"] ?? q["obfs_password"])?.removingPercentEncoding
        if let up = q["upmbps"] ?? q["up"] { cfg.upMbps = Int(up) }
        if let down = q["downmbps"] ?? q["down"] { cfg.downMbps = Int(down) }
        cfg.fingerprint = q["fp"]
        return cfg
    }

    // MARK: - TUIC (sing-box core)
    //
    // tuic://uuid:password@host:port?sni=...&congestion_control=bbr
    //   &udp_relay_mode=native&alpn=h3&allow_insecure=0#name

    private static func parseTUIC(_ line: String) throws -> ProxyConfig {
        guard let comps = URLComponents(string: line),
              let host = comps.host,
              let port = comps.port else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: fragmentName(comps) ?? host,
                              proto: .tuic, address: host, port: port)
        // userinfo = uuid:password
        cfg.uuid = comps.user?.removingPercentEncoding ?? comps.user
        if let pwd = comps.password {
            cfg.password = pwd.removingPercentEncoding ?? pwd
        }
        let q = queryDict(comps)
        cfg.security = .tls
        cfg.sni = q["sni"] ?? q["peer"]
        cfg.allowInsecure = (q["allow_insecure"] == "1" || q["allow_insecure"] == "true"
                             || q["insecure"] == "1" || q["insecure"] == "true")
        if let alpn = q["alpn"]?.removingPercentEncoding {
            cfg.alpn = alpn.split(separator: ",").map(String.init)
        }
        cfg.congestionControl = q["congestion_control"] ?? q["congestion"]
        cfg.udpRelayMode = q["udp_relay_mode"]
        cfg.fingerprint = q["fp"]
        return cfg
    }

    // MARK: - AnyTLS (sing-box core)
    //
    // anytls://password@host:port?sni=...&insecure=0&alpn=h2,http/1.1#name

    private static func parseAnyTLS(_ line: String) throws -> ProxyConfig {
        guard let comps = URLComponents(string: line),
              let host = comps.host,
              let port = comps.port else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: fragmentName(comps) ?? host,
                              proto: .anytls, address: host, port: port)
        if let user = comps.user {
            cfg.password = user.removingPercentEncoding ?? user
        }
        // Some share formats put the password in the password slot instead.
        if cfg.password == nil, let pwd = comps.password {
            cfg.password = pwd.removingPercentEncoding ?? pwd
        }
        let q = queryDict(comps)
        cfg.security = .tls
        cfg.sni = q["sni"] ?? q["peer"] ?? q["host"]
        cfg.allowInsecure = (q["insecure"] == "1" || q["insecure"] == "true"
                             || q["allowInsecure"] == "1" || q["allowInsecure"] == "true")
        if let alpn = q["alpn"]?.removingPercentEncoding {
            cfg.alpn = alpn.split(separator: ",").map(String.init)
        }
        cfg.fingerprint = q["fp"]
        return cfg
    }

    // MARK: - WireGuard (sing-box endpoint)
    //
    // Two accepted forms:
    //  1. URI: wireguard://<privkey>@host:port?publickey=...&address=10.0.0.2/32
    //          &reserved=0,0,0&mtu=1408&presharedkey=...#name
    //  2. A standard wg-quick .conf paste with [Interface]/[Peer] sections.

    private static func parseWireGuard(_ line: String) throws -> ProxyConfig {
        guard let comps = URLComponents(string: line),
              let host = comps.host,
              let port = comps.port else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: fragmentName(comps) ?? host,
                              proto: .wireguard, address: host, port: port)
        // userinfo carries the local private key.
        if let user = comps.user {
            cfg.privateKey = (user.removingPercentEncoding ?? user)
        }
        let q = queryDict(comps)
        cfg.privateKey = cfg.privateKey ?? (q["privatekey"] ?? q["secretkey"])?.removingPercentEncoding
        cfg.peerPublicKey = (q["publickey"] ?? q["public_key"] ?? q["peer_public_key"])?.removingPercentEncoding
        cfg.presharedKey = (q["presharedkey"] ?? q["pre_shared_key"])?.removingPercentEncoding
        if let addr = (q["address"] ?? q["ip"])?.removingPercentEncoding {
            cfg.localAddresses = addr.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
        }
        if let mtu = q["mtu"] { cfg.mtu = Int(mtu) }
        if let reserved = q["reserved"]?.removingPercentEncoding {
            let parts = reserved.split(separator: ",").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            }
            if parts.count == 3 { cfg.reserved = parts }
        }
        return cfg
    }

    /// Parses a wg-quick `.conf` text into a `ProxyConfig`. Public so the add
    /// sheet can detect and feed raw config pastes that aren't URI links.
    static func parseWireGuardConf(_ text: String, name: String? = nil) -> ProxyConfig? {
        var privateKey: String?
        var addresses: [String] = []
        var mtu: Int?
        var peerPublicKey: String?
        var presharedKey: String?
        var endpointHost: String?
        var endpointPort: Int?

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let l = rawLine.trimmingCharacters(in: .whitespaces)
            guard let eq = l.firstIndex(of: "="), !l.hasPrefix("#"), !l.hasPrefix("[") else { continue }
            let key = l[l.startIndex..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = l[l.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "privatekey":   privateKey = value
            case "address":      addresses = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            case "mtu":          mtu = Int(value)
            case "publickey":    peerPublicKey = value
            case "presharedkey": presharedKey = value
            case "endpoint":
                let (h, p) = splitHostPort(value)
                endpointHost = h; endpointPort = p
            default: break
            }
        }

        guard let host = endpointHost, let port = endpointPort,
              privateKey != nil, peerPublicKey != nil else {
            return nil
        }
        var cfg = ProxyConfig(name: name ?? host, proto: .wireguard, address: host, port: port)
        cfg.privateKey = privateKey
        cfg.peerPublicKey = peerPublicKey
        cfg.presharedKey = presharedKey
        cfg.localAddresses = addresses.isEmpty ? nil : addresses
        cfg.mtu = mtu
        return cfg
    }

    // MARK: - Shared helpers
    private static func applyTransport(_ cfg: inout ProxyConfig, query q: [String: String]) {
        if let net = q["type"] ?? q["net"] {
            cfg.network = TransportNetwork(rawValue: net) ?? .tcp
        }
        cfg.path = q["path"]?.removingPercentEncoding ?? q["path"]
        cfg.host = q["host"]?.removingPercentEncoding ?? q["host"]
        cfg.serviceName = q["serviceName"]?.removingPercentEncoding ?? q["serviceName"]
        // XHTTP transport (a.k.a. SplitHTTP). `mode` selects the upload strategy.
        cfg.xhttpMode = q["mode"]
        // Padding can arrive either as a flat `x_padding_bytes` param or nested
        // inside the `extra` JSON object (xPaddingBytes). Prefer the explicit one.
        if let pad = q["x_padding_bytes"] ?? q["xPaddingBytes"] {
            cfg.xPaddingBytes = pad.removingPercentEncoding ?? pad
        } else if let extraRaw = q["extra"]?.removingPercentEncoding,
                  let data = extraRaw.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pad = json["xPaddingBytes"] as? String {
            cfg.xPaddingBytes = pad
        }
    }

    private static func applySecurity(_ cfg: inout ProxyConfig, query q: [String: String]) {
        if let sec = q["security"] {
            cfg.security = StreamSecurity(rawValue: sec) ?? .none
        }
        cfg.sni = q["sni"] ?? q["peer"] ?? cfg.host
        cfg.fingerprint = q["fp"]
        if let alpn = q["alpn"]?.removingPercentEncoding {
            cfg.alpn = alpn.split(separator: ",").map(String.init)
        }
        cfg.allowInsecure = (q["allowInsecure"] == "1" || q["allowInsecure"] == "true")
        // Reality
        cfg.publicKey = q["pbk"]
        cfg.shortId = q["sid"]
        cfg.spiderX = q["spx"]?.removingPercentEncoding
    }

    private static func queryDict(_ comps: URLComponents) -> [String: String] {
        var dict: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            dict[item.name] = item.value
        }
        return dict
    }

    private static func fragmentName(_ comps: URLComponents) -> String? {
        guard let frag = comps.fragment, !frag.isEmpty else { return nil }
        return frag.removingPercentEncoding ?? frag
    }

    private static func splitHostPort(_ s: String) -> (String?, Int?) {
        guard let colon = s.lastIndex(of: ":") else { return (s, nil) }
        let host = String(s[s.startIndex..<colon])
        let port = Int(s[s.index(after: colon)...])
        return (host, port)
    }

    /// Decode base64 tolerant of URL-safe alphabet and missing padding.
    static func decodeBase64(_ s: String) -> Data? {
        var str = s
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let remainder = str.count % 4
        if remainder > 0 {
            str.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: str)
    }
}
