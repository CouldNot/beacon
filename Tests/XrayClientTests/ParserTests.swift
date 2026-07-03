import XCTest
@testable import XrayClient

final class LinkParserTests: XCTestCase {

    func testVLESSReality() throws {
        let link = "vless://11111111-2222-3333-4444-555555555555@example.com:443?encryption=none&security=reality&sni=www.microsoft.com&fp=chrome&pbk=somepublickey&sid=abcd&type=tcp&flow=xtls-rprx-vision#MyServer"
        let cfg = try LinkParser.parse(link)
        XCTAssertEqual(cfg.proto, .vless)
        XCTAssertEqual(cfg.address, "example.com")
        XCTAssertEqual(cfg.port, 443)
        XCTAssertEqual(cfg.uuid, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(cfg.security, .reality)
        XCTAssertEqual(cfg.sni, "www.microsoft.com")
        XCTAssertEqual(cfg.fingerprint, "chrome")
        XCTAssertEqual(cfg.publicKey, "somepublickey")
        XCTAssertEqual(cfg.shortId, "abcd")
        XCTAssertEqual(cfg.flow, "xtls-rprx-vision")
        XCTAssertEqual(cfg.name, "MyServer")
    }

    func testVLESSWebSocketTLS() throws {        let link = "vless://abc@host.net:8443?encryption=none&security=tls&type=ws&path=%2Fwspath&host=cdn.host.net&sni=cdn.host.net#WS"
        let cfg = try LinkParser.parse(link)
        XCTAssertEqual(cfg.network, .ws)
        XCTAssertEqual(cfg.security, .tls)
        XCTAssertEqual(cfg.path, "/wspath")
        XCTAssertEqual(cfg.host, "cdn.host.net")
    }

    func testVLESSXHTTPPostQuantumReality() throws {
        let link = "vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443?type=xhttp&encryption=mlkem768x25519plus.native.0rtt.ANXtyy6hcZrJHshgKIEe9FuUa-p-oJvtMFc6C_0njDc&path=%2Fajax%2Flibs%2Fjquery%2F3.7.1%2Fjquery.min.js&host=cdnjs.cloudflare.com&mode=stream-up&x_padding_bytes=100-1000&extra=%7B%22xPaddingBytes%22%3A%22100-1000%22%7D&security=reality&pbk=n0gvFidjvOZT4iKxqi0VJpeRVky1gFb33bc4FHV8fzc&fp=firefox&sni=mirror.yandex.ru&sid=#PQ"
        let cfg = try LinkParser.parse(link)
        XCTAssertEqual(cfg.proto, .vless)
        XCTAssertEqual(cfg.network, .xhttp)
        XCTAssertEqual(cfg.security, .reality)
        XCTAssertEqual(cfg.encryption, "mlkem768x25519plus.native.0rtt.ANXtyy6hcZrJHshgKIEe9FuUa-p-oJvtMFc6C_0njDc")
        XCTAssertEqual(cfg.path, "/ajax/libs/jquery/3.7.1/jquery.min.js")
        XCTAssertEqual(cfg.host, "cdnjs.cloudflare.com")
        XCTAssertEqual(cfg.xhttpMode, "stream-up")
        XCTAssertEqual(cfg.xPaddingBytes, "100-1000")
        XCTAssertEqual(cfg.sni, "mirror.yandex.ru")
        XCTAssertEqual(cfg.fingerprint, "firefox")
        XCTAssertEqual(cfg.publicKey, "n0gvFidjvOZT4iKxqi0VJpeRVky1gFb33bc4FHV8fzc")
    }

    func testVMessBase64() throws {
        let json = """
        {"v":"2","ps":"VMessNode","add":"1.2.3.4","port":"443","id":"aaaa-bbbb","aid":"0","net":"ws","type":"none","host":"h.com","path":"/p","tls":"tls"}
        """
        let b64 = Data(json.utf8).base64EncodedString()
        let cfg = try LinkParser.parse("vmess://\(b64)")
        XCTAssertEqual(cfg.proto, .vmess)
        XCTAssertEqual(cfg.address, "1.2.3.4")
        XCTAssertEqual(cfg.port, 443)
        XCTAssertEqual(cfg.uuid, "aaaa-bbbb")
        XCTAssertEqual(cfg.network, .ws)
        XCTAssertEqual(cfg.security, .tls)
        XCTAssertEqual(cfg.name, "VMessNode")
    }

    func testTrojanDefaultsTLS() throws {
        let cfg = try LinkParser.parse("trojan://pass123@t.example.com:443?sni=t.example.com#Trojan")
        XCTAssertEqual(cfg.proto, .trojan)
        XCTAssertEqual(cfg.password, "pass123")
        XCTAssertEqual(cfg.security, .tls)
        XCTAssertEqual(cfg.sni, "t.example.com")
    }

    func testShadowsocksSIP002() throws {
        // userinfo = base64("aes-256-gcm:secretpass")
        let userinfo = Data("aes-256-gcm:secretpass".utf8).base64EncodedString()
        let cfg = try LinkParser.parse("ss://\(userinfo)@ss.example.com:8388#SS")
        XCTAssertEqual(cfg.proto, .shadowsocks)
        XCTAssertEqual(cfg.method, "aes-256-gcm")
        XCTAssertEqual(cfg.password, "secretpass")
        XCTAssertEqual(cfg.address, "ss.example.com")
        XCTAssertEqual(cfg.port, 8388)
    }

    func testHysteria2() throws {
        let link = "hysteria2://mypassword@hy2.example.com:443?sni=bing.com&obfs=salamander&obfs-password=obfssecret&insecure=1&alpn=h3#HY2"
        let cfg = try LinkParser.parse(link)
        XCTAssertEqual(cfg.proto, .hysteria2)
        XCTAssertEqual(cfg.engine, .singbox)
        XCTAssertEqual(cfg.address, "hy2.example.com")
        XCTAssertEqual(cfg.port, 443)
        XCTAssertEqual(cfg.password, "mypassword")
        XCTAssertEqual(cfg.sni, "bing.com")
        XCTAssertEqual(cfg.obfs, "salamander")
        XCTAssertEqual(cfg.obfsPassword, "obfssecret")
        XCTAssertTrue(cfg.allowInsecure)
        XCTAssertEqual(cfg.alpn, ["h3"])
        XCTAssertEqual(cfg.name, "HY2")
    }

    func testHy2AliasScheme() throws {
        let cfg = try LinkParser.parse("hy2://pw@h.com:8443?sni=h.com#A")
        XCTAssertEqual(cfg.proto, .hysteria2)
        XCTAssertEqual(cfg.password, "pw")
    }

    func testTUIC() throws {
        let link = "tuic://11111111-2222-3333-4444-555555555555:tuicpass@tuic.example.com:443?sni=cloudflare.com&congestion_control=bbr&udp_relay_mode=native&alpn=h3#TUIC"
        let cfg = try LinkParser.parse(link)
        XCTAssertEqual(cfg.proto, .tuic)
        XCTAssertEqual(cfg.engine, .singbox)
        XCTAssertEqual(cfg.uuid, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(cfg.password, "tuicpass")
        XCTAssertEqual(cfg.sni, "cloudflare.com")
        XCTAssertEqual(cfg.congestionControl, "bbr")
        XCTAssertEqual(cfg.udpRelayMode, "native")
    }

    func testAnyTLS() throws {
        let link = "anytls://secretpw@a.example.com:8443?sni=example.com&insecure=1&alpn=h2,http/1.1#AnyTLS"
        let cfg = try LinkParser.parse(link)
        XCTAssertEqual(cfg.proto, .anytls)
        XCTAssertEqual(cfg.engine, .singbox)
        XCTAssertEqual(cfg.password, "secretpw")
        XCTAssertEqual(cfg.sni, "example.com")
        XCTAssertTrue(cfg.allowInsecure)
        XCTAssertEqual(cfg.alpn, ["h2", "http/1.1"])
    }

    func testWireGuardURI() throws {
        let link = "wireguard://cHJpdmF0ZWtleQ@wg.example.com:51820?publickey=cHVibGlja2V5&address=10.0.0.2/32&mtu=1408&reserved=1,2,3#WG"
        let cfg = try LinkParser.parse(link)
        XCTAssertEqual(cfg.proto, .wireguard)
        XCTAssertEqual(cfg.engine, .singbox)
        XCTAssertEqual(cfg.address, "wg.example.com")
        XCTAssertEqual(cfg.port, 51820)
        XCTAssertEqual(cfg.privateKey, "cHJpdmF0ZWtleQ")
        XCTAssertEqual(cfg.peerPublicKey, "cHVibGlja2V5")
        XCTAssertEqual(cfg.localAddresses, ["10.0.0.2/32"])
        XCTAssertEqual(cfg.mtu, 1408)
        XCTAssertEqual(cfg.reserved, [1, 2, 3])
    }

    func testWireGuardConf() {
        let conf = """
        [Interface]
        PrivateKey = privkeybase64
        Address = 10.0.0.3/32
        MTU = 1408
        [Peer]
        PublicKey = pubkeybase64
        Endpoint = 5.6.7.8:51820
        AllowedIPs = 0.0.0.0/0
        """
        let cfg = LinkParser.parseWireGuardConf(conf, name: "WGConf")
        XCTAssertNotNil(cfg)
        XCTAssertEqual(cfg?.proto, .wireguard)
        XCTAssertEqual(cfg?.address, "5.6.7.8")
        XCTAssertEqual(cfg?.port, 51820)
        XCTAssertEqual(cfg?.privateKey, "privkeybase64")
        XCTAssertEqual(cfg?.peerPublicKey, "pubkeybase64")
        XCTAssertEqual(cfg?.localAddresses, ["10.0.0.3/32"])
    }

    func testEngineRouting() {
        XCTAssertEqual(ProxyConfig(name: "", proto: .vless, address: "h", port: 1).engine, .xray)
        XCTAssertEqual(ProxyConfig(name: "", proto: .trojan, address: "h", port: 1).engine, .xray)
        XCTAssertEqual(ProxyConfig(name: "", proto: .hysteria2, address: "h", port: 1).engine, .singbox)
        XCTAssertEqual(ProxyConfig(name: "", proto: .tuic, address: "h", port: 1).engine, .singbox)
        XCTAssertEqual(ProxyConfig(name: "", proto: .wireguard, address: "h", port: 1).engine, .singbox)
        XCTAssertEqual(ProxyConfig(name: "", proto: .anytls, address: "h", port: 1).engine, .singbox)
    }

    func testParseManySkipsInvalid() {
        let text = """
        vless://abc@h1.com:443?encryption=none#A
        not-a-link
        trojan://p@h2.com:443#B
        """
        let result = LinkParser.parseMany(text)
        XCTAssertEqual(result.count, 2)
    }

    func testUnsupportedScheme() {
        XCTAssertThrowsError(try LinkParser.parse("ftp://whatever"))
    }
}

final class XrayConfigBuilderTests: XCTestCase {

    func testVLESSConfigStructure() throws {
        var cfg = ProxyConfig(name: "t", proto: .vless, address: "h.com", port: 443)
        cfg.uuid = "uuid-1"
        cfg.security = .reality
        cfg.publicKey = "pbk"
        cfg.flow = "xtls-rprx-vision"

        let dict = XrayConfigBuilder.build(for: cfg)
        let outbounds = dict["outbounds"] as! [[String: Any]]
        let proxy = outbounds.first { ($0["tag"] as? String) == "proxy" }!
        XCTAssertEqual(proxy["protocol"] as? String, "vless")

        let settings = proxy["settings"] as! [String: Any]
        let vnext = settings["vnext"] as! [[String: Any]]
        XCTAssertEqual(vnext[0]["address"] as? String, "h.com")
        let user = (vnext[0]["users"] as! [[String: Any]])[0]
        XCTAssertEqual(user["id"] as? String, "uuid-1")
        XCTAssertEqual(user["flow"] as? String, "xtls-rprx-vision")

        let stream = proxy["streamSettings"] as! [String: Any]
        XCTAssertEqual(stream["security"] as? String, "reality")
        let reality = stream["realitySettings"] as! [String: Any]
        XCTAssertEqual(reality["publicKey"] as? String, "pbk")
    }

    func testInboundsPresent() throws {
        let cfg = ProxyConfig(name: "t", proto: .trojan, address: "h", port: 1)
        let dict = XrayConfigBuilder.build(for: cfg)
        let inbounds = dict["inbounds"] as! [[String: Any]]
        let protocols = inbounds.compactMap { $0["protocol"] as? String }
        XCTAssertTrue(protocols.contains("socks"))
        XCTAssertTrue(protocols.contains("http"))
    }

    func testProducesValidJSON() throws {
        let cfg = ProxyConfig(name: "t", proto: .shadowsocks, address: "h", port: 1)
        let data = try XrayConfigBuilder.jsonData(for: cfg)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testXHTTPStreamSettings() throws {
        var cfg = ProxyConfig(name: "t", proto: .vless, address: "1.2.3.4", port: 443)
        cfg.uuid = "uuid-1"
        cfg.encryption = "mlkem768x25519plus.native.0rtt.SOMEKEY"
        cfg.network = .xhttp
        cfg.security = .reality
        cfg.publicKey = "pbk"
        cfg.sni = "mirror.yandex.ru"
        cfg.host = "cdnjs.cloudflare.com"
        cfg.path = "/p.js"
        cfg.xhttpMode = "stream-up"
        cfg.xPaddingBytes = "100-1000"

        let dict = XrayConfigBuilder.build(for: cfg)
        let outbounds = dict["outbounds"] as! [[String: Any]]
        let proxy = outbounds.first { ($0["tag"] as? String) == "proxy" }!
        let user = (((proxy["settings"] as! [String: Any])["vnext"] as! [[String: Any]])[0]["users"] as! [[String: Any]])[0]
        XCTAssertEqual(user["encryption"] as? String, "mlkem768x25519plus.native.0rtt.SOMEKEY")

        let stream = proxy["streamSettings"] as! [String: Any]
        XCTAssertEqual(stream["network"] as? String, "xhttp")
        let xhttp = stream["xhttpSettings"] as! [String: Any]
        XCTAssertEqual(xhttp["host"] as? String, "cdnjs.cloudflare.com")
        XCTAssertEqual(xhttp["path"] as? String, "/p.js")
        XCTAssertEqual(xhttp["mode"] as? String, "stream-up")
        let extra = xhttp["extra"] as! [String: Any]
        XCTAssertEqual(extra["xPaddingBytes"] as? String, "100-1000")
    }
}

final class SingBoxConfigBuilderTests: XCTestCase {

    func testHysteria2Outbound() throws {
        var cfg = ProxyConfig(name: "t", proto: .hysteria2, address: "h.com", port: 443)
        cfg.password = "pw"
        cfg.sni = "bing.com"
        cfg.obfs = "salamander"
        cfg.obfsPassword = "obfspw"
        cfg.allowInsecure = true

        let dict = SingBoxConfigBuilder.build(for: cfg)
        let outbounds = dict["outbounds"] as! [[String: Any]]
        let proxy = outbounds.first { ($0["tag"] as? String) == "proxy" }!
        XCTAssertEqual(proxy["type"] as? String, "hysteria2")
        XCTAssertEqual(proxy["server"] as? String, "h.com")
        XCTAssertEqual(proxy["server_port"] as? Int, 443)
        XCTAssertEqual(proxy["password"] as? String, "pw")
        let obfs = proxy["obfs"] as! [String: Any]
        XCTAssertEqual(obfs["type"] as? String, "salamander")
        XCTAssertEqual(obfs["password"] as? String, "obfspw")
        let tls = proxy["tls"] as! [String: Any]
        XCTAssertEqual(tls["server_name"] as? String, "bing.com")
        XCTAssertEqual(tls["insecure"] as? Bool, true)
        XCTAssertEqual(tls["alpn"] as? [String], ["h3"])
    }

    func testTUICOutbound() throws {
        var cfg = ProxyConfig(name: "t", proto: .tuic, address: "h.com", port: 443)
        cfg.uuid = "uuid-1"
        cfg.password = "pw"
        cfg.sni = "cf.com"
        cfg.congestionControl = "bbr"
        cfg.udpRelayMode = "native"

        let dict = SingBoxConfigBuilder.build(for: cfg)
        let proxy = (dict["outbounds"] as! [[String: Any]]).first { ($0["tag"] as? String) == "proxy" }!
        XCTAssertEqual(proxy["type"] as? String, "tuic")
        XCTAssertEqual(proxy["uuid"] as? String, "uuid-1")
        XCTAssertEqual(proxy["password"] as? String, "pw")
        XCTAssertEqual(proxy["congestion_control"] as? String, "bbr")
        XCTAssertEqual(proxy["udp_relay_mode"] as? String, "native")
    }

    func testInboundsAndDefaults() throws {
        var cfg = ProxyConfig(name: "t", proto: .tuic, address: "h.com", port: 443)
        cfg.uuid = "u"; cfg.password = "p"
        let dict = SingBoxConfigBuilder.build(for: cfg)
        let inbounds = dict["inbounds"] as! [[String: Any]]
        let types = inbounds.compactMap { $0["type"] as? String }
        XCTAssertTrue(types.contains("socks"))
        XCTAssertTrue(types.contains("http"))
        // TUIC defaults applied when link omits them.
        let proxy = (dict["outbounds"] as! [[String: Any]]).first { ($0["tag"] as? String) == "proxy" }!
        XCTAssertEqual(proxy["congestion_control"] as? String, "bbr")
        XCTAssertEqual(proxy["udp_relay_mode"] as? String, "native")
    }

    func testProducesValidJSON() throws {
        var cfg = ProxyConfig(name: "t", proto: .hysteria2, address: "h", port: 1)
        cfg.password = "p"
        let data = try SingBoxConfigBuilder.jsonData(for: cfg)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testAnyTLSOutbound() throws {
        var cfg = ProxyConfig(name: "t", proto: .anytls, address: "h.com", port: 8443)
        cfg.password = "pw"; cfg.sni = "e.com"
        let dict = SingBoxConfigBuilder.build(for: cfg)
        let proxy = (dict["outbounds"] as! [[String: Any]]).first { ($0["tag"] as? String) == "proxy" }!
        XCTAssertEqual(proxy["type"] as? String, "anytls")
        XCTAssertEqual(proxy["password"] as? String, "pw")
        let tls = proxy["tls"] as! [String: Any]
        XCTAssertEqual(tls["server_name"] as? String, "e.com")
    }

    func testWireGuardEndpoint() throws {
        var cfg = ProxyConfig(name: "t", proto: .wireguard, address: "h.com", port: 51820)
        cfg.privateKey = "priv"; cfg.peerPublicKey = "pub"
        cfg.localAddresses = ["10.0.0.2/32"]; cfg.mtu = 1408
        let dict = SingBoxConfigBuilder.build(for: cfg)
        // WireGuard goes in the top-level `endpoints` array, not `outbounds`.
        let endpoints = dict["endpoints"] as! [[String: Any]]
        let ep = endpoints[0]
        XCTAssertEqual(ep["type"] as? String, "wireguard")
        XCTAssertEqual(ep["private_key"] as? String, "priv")
        XCTAssertEqual(ep["mtu"] as? Int, 1408)
        let peer = (ep["peers"] as! [[String: Any]])[0]
        XCTAssertEqual(peer["public_key"] as? String, "pub")
        XCTAssertEqual(peer["address"] as? String, "h.com")
        XCTAssertEqual(peer["port"] as? Int, 51820)
        // outbounds should NOT contain a proxy tag for wireguard.
        let outTags = (dict["outbounds"] as! [[String: Any]]).compactMap { $0["tag"] as? String }
        XCTAssertFalse(outTags.contains("proxy"))
    }
}

final class LinkBuilderTests: XCTestCase {

    /// Round-trips a link through parse -> build -> parse and checks key fields.
    private func roundTrip(_ link: String, file: StaticString = #filePath, line: UInt = #line) throws -> ProxyConfig {
        let a = try LinkParser.parse(link)
        let rebuilt = LinkBuilder.link(for: a)
        return try LinkParser.parse(rebuilt)
    }

    func testVLESSRoundTrip() throws {
        let link = "vless://11111111-2222-3333-4444-555555555555@example.com:443?encryption=none&security=reality&sni=www.microsoft.com&fp=chrome&pbk=somekey&sid=abcd&type=tcp&flow=xtls-rprx-vision#MyServer"
        let cfg = try roundTrip(link)
        XCTAssertEqual(cfg.proto, .vless)
        XCTAssertEqual(cfg.uuid, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(cfg.security, .reality)
        XCTAssertEqual(cfg.publicKey, "somekey")
        XCTAssertEqual(cfg.flow, "xtls-rprx-vision")
        XCTAssertEqual(cfg.name, "MyServer")
    }

    func testHysteria2RoundTrip() throws {
        let link = "hysteria2://pw@h.com:443?sni=bing.com&obfs=salamander&obfs-password=op&insecure=1#HY2"
        let cfg = try roundTrip(link)
        XCTAssertEqual(cfg.proto, .hysteria2)
        XCTAssertEqual(cfg.password, "pw")
        XCTAssertEqual(cfg.obfs, "salamander")
        XCTAssertEqual(cfg.obfsPassword, "op")
        XCTAssertTrue(cfg.allowInsecure)
    }

    func testTUICRoundTrip() throws {
        let link = "tuic://uuid-1:pw@h.com:443?sni=cf.com&congestion_control=bbr&udp_relay_mode=native#T"
        let cfg = try roundTrip(link)
        XCTAssertEqual(cfg.proto, .tuic)
        XCTAssertEqual(cfg.uuid, "uuid-1")
        XCTAssertEqual(cfg.password, "pw")
        XCTAssertEqual(cfg.congestionControl, "bbr")
    }

    func testWireGuardRoundTrip() throws {
        let link = "wireguard://cHJpdg@h.com:51820?publickey=cHVi&address=10.0.0.2/32&mtu=1408#WG"
        let cfg = try roundTrip(link)
        XCTAssertEqual(cfg.proto, .wireguard)
        XCTAssertEqual(cfg.privateKey, "cHJpdg")
        XCTAssertEqual(cfg.peerPublicKey, "cHVi")
        XCTAssertEqual(cfg.mtu, 1408)
    }

    // MARK: - Ping transport classification
    //
    // QUIC protocols (Hysteria2/TUIC) get a real QUIC handshake probe; WireGuard
    // has no TCP/QUIC listener so it falls back to ICMP; everything else (incl.
    // AnyTLS, which is TLS-over-TCP) uses a plain TCP connect.

    func testPingStrategyClassification() {
        func cfg(_ proto: ProxyProtocol) -> ProxyConfig {
            ProxyConfig(name: "x", proto: proto, address: "h", port: 443)
        }
        XCTAssertEqual(cfg(.hysteria2).pingStrategy, .quic)
        XCTAssertEqual(cfg(.tuic).pingStrategy, .quic)
        XCTAssertEqual(cfg(.wireguard).pingStrategy, .icmp)
        XCTAssertEqual(cfg(.vless).pingStrategy, .tcp)
        XCTAssertEqual(cfg(.vmess).pingStrategy, .tcp)
        XCTAssertEqual(cfg(.trojan).pingStrategy, .tcp)
        XCTAssertEqual(cfg(.shadowsocks).pingStrategy, .tcp)
        XCTAssertEqual(cfg(.anytls).pingStrategy, .tcp)
    }
}
