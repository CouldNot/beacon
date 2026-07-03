import Foundation

/// A subscription profile: a named group of servers fetched from one URL,
/// with optional traffic/expiry metadata (parsed from the Subscription-Userinfo
/// HTTP header that most panels return).
struct Subscription: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var url: String?               // nil for the manual/local group
    var servers: [ProxyConfig] = []
    var lastUpdated: Date?
    var autoUpdate: Bool = true
    var isCollapsed: Bool = false
    var note: String?              // free-form description

    // Traffic accounting (bytes). nil when the panel doesn't report it.
    var uploadBytes: Int64?
    var downloadBytes: Int64?
    var totalBytes: Int64?
    var expiresAt: Date?           // from `expire=` epoch seconds

    init(name: String, url: String? = nil) {
        self.name = name
        self.url = url
    }

    var usedBytes: Int64? {
        guard let up = uploadBytes, let down = downloadBytes else { return nil }
        return up + down
    }

    /// 0...1 fraction of traffic used, when both used and total are known.
    var usageFraction: Double? {
        guard let used = usedBytes, let total = totalBytes, total > 0 else { return nil }
        return min(1.0, Double(used) / Double(total))
    }

    var isManual: Bool { url == nil }
}

/// Parses the `Subscription-Userinfo` response header, e.g.
/// `upload=1234; download=5678; total=10737418240; expire=1700000000`.
enum SubscriptionUserinfo {
    struct Info {
        var upload: Int64?
        var download: Int64?
        var total: Int64?
        var expire: Date?
    }

    static func parse(_ header: String) -> Info {
        var info = Info()
        for pair in header.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = kv[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = kv[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "upload":   info.upload = Int64(value)
            case "download": info.download = Int64(value)
            case "total":    info.total = Int64(value)
            case "expire":
                if let epoch = TimeInterval(value), epoch > 0 {
                    info.expire = Date(timeIntervalSince1970: epoch)
                }
            default: break
            }
        }
        return info
    }
}

/// Human-readable byte formatting (GB/MB/etc.).
enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        return formatter.string(fromByteCount: bytes)
    }
}
