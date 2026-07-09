import Foundation

/// Supported proxy protocols. VLESS/VMess/Trojan/SS run on the Xray core;
/// Hysteria2/TUIC are QUIC-based and run on the sing-box core.
enum ProxyProtocol: String, Codable, CaseIterable {
    case vless
    case vmess
    case trojan
    case shadowsocks = "ss"
    case hysteria2
    case tuic
    case wireguard
    case anytls
}

/// Which bundled core engine drives a given protocol.
enum CoreEngine {
    case xray
    case singbox
}

/// Transport-layer network used by the outbound stream.
enum TransportNetwork: String, Codable {
    case tcp
    case ws
    case grpc
    case http
    case kcp
    case quic
    case xhttp
}

/// Security applied on top of the transport.
enum StreamSecurity: String, Codable, CaseIterable {
    case none
    case tls
    case reality
}

/// A single proxy server entry. This is the canonical representation parsed from
/// share links / subscriptions and later compiled into an Xray-core config.
struct ProxyConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()

    // Display
    var name: String

    // Core connection
    var proto: ProxyProtocol
    var address: String
    var port: Int

    // Auth / identity
    var uuid: String?          // vless / vmess user id
    var password: String?      // trojan password / shadowsocks password
    var method: String?        // shadowsocks cipher (e.g. aes-256-gcm)
    var alterId: Int?          // vmess legacy alterId
    var flow: String?          // vless flow, e.g. xtls-rprx-vision
    var encryption: String?    // vless encryption (usually "none")

    // Transport
    var network: TransportNetwork = .tcp
    var security: StreamSecurity = .none

    // TLS / Reality
    var sni: String?
    var alpn: [String]?
    var fingerprint: String?   // utls fingerprint, e.g. chrome
    var allowInsecure: Bool = false
    var publicKey: String?     // reality
    var shortId: String?       // reality
    var spiderX: String?       // reality

    // ws / http / grpc specifics
    var path: String?
    var host: String?          // ws/http Host header
    var serviceName: String?   // grpc

    // xhttp specifics
    var xhttpMode: String?     // "auto" | "packet-up" | "stream-up" | "stream-one"
    var xPaddingBytes: String? // e.g. "100-1000"

    // Hysteria2 / TUIC (sing-box core)
    var obfs: String?              // hysteria2 obfs type, e.g. "salamander"
    var obfsPassword: String?      // hysteria2 obfs password
    var congestionControl: String? // tuic: "bbr" | "cubic" | "new_reno"
    var udpRelayMode: String?      // tuic: "native" | "quic"
    var upMbps: Int?               // hysteria2 optional bandwidth hint
    var downMbps: Int?

    // WireGuard (sing-box endpoint)
    var privateKey: String?        // wireguard local private key (base64)
    var peerPublicKey: String?     // wireguard peer public key (base64)
    var presharedKey: String?      // optional wireguard PSK
    var localAddresses: [String]?  // interface addresses, e.g. ["10.0.0.2/32"]
    var mtu: Int?
    var reserved: [Int]?           // wireguard reserved bytes (3 ints)

    /// The core engine that handles this protocol.
    var engine: CoreEngine {
        switch proto {
        case .vless, .vmess, .trojan, .shadowsocks:        return .xray
        case .hysteria2, .tuic, .wireguard, .anytls:       return .singbox
        }
    }

    /// How the ping tester should probe this server for reachability + RTT.
    enum PingStrategy: Sendable, Equatable {
        case tcp   // standard TCP connect (has a TCP listener)
        case quic  // real QUIC + TLS handshake (Hysteria2 / TUIC)
        case icmp  // ICMP echo (WireGuard — no TCP listener, not QUIC either)
    }

    /// Picks the probe transport. Hysteria2/TUIC speak QUIC, so we run a genuine
    /// QUIC+TLS handshake and time it — a TCP connect would always "time out"
    /// since they expose no TCP port. WireGuard is a UDP/Noise protocol with no
    /// TCP port and no QUIC, so it falls back to ICMP echo. AnyTLS, despite
    /// running on the sing-box core, speaks ordinary TLS over TCP.
    var pingStrategy: PingStrategy {
        switch proto {
        case .hysteria2, .tuic:                              return .quic
        case .wireguard:                                     return .icmp
        case .vless, .vmess, .trojan, .shadowsocks, .anytls: return .tcp
        }
    }

    init(
        name: String,
        proto: ProxyProtocol,
        address: String,
        port: Int
    ) {
        self.name = name
        self.proto = proto
        self.address = address
        self.port = port
    }
}
