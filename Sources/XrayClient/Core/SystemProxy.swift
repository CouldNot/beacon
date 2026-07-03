import Foundation

/// Controls the macOS system-wide proxy via `networksetup`.
///
/// Sets the SOCKS and HTTP/HTTPS proxies for the primary network service to
/// point at the local Xray inbounds, and restores them on disconnect.
enum SystemProxy {

    /// Returns the name of the network service that currently carries the
    /// default route (i.e. the interface actually used for internet access).
    static func primaryService() -> String? {
        // 1. Find the interface backing the default route, e.g. "en0".
        guard let iface = defaultRouteInterface() else {
            return firstActiveService()
        }
        // 2. Map that BSD device to a network service name via the service order
        //    listing, whose blocks look like:
        //      (1) Wi-Fi
        //      (Hardware Port: Wi-Fi, Device: en0)
        guard let output = run(["-listnetworkserviceorder"]) else { return nil }
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for (i, line) in lines.enumerated() {
            guard line.contains("Device: \(iface))") else { continue }
            // The service name is on the preceding "(N) Name" line.
            if i > 0, let name = serviceName(from: lines[i - 1]) {
                return name
            }
        }
        return firstActiveService()
    }

    /// Parses the BSD interface name (e.g. en0) for the default route.
    private static func defaultRouteInterface() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/sbin/route")
        proc.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return nil }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("interface:") {
                return t.replacingOccurrences(of: "interface:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Extracts "Name" from a "(N) Name" line, skipping disabled (*) services.
    private static func serviceName(from line: String) -> String? {
        guard line.hasPrefix("("), let close = line.firstIndex(of: ")") else { return nil }
        let name = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
        if name.isEmpty || name.hasPrefix("*") { return nil }
        return name
    }

    /// Fallback: first enabled service whose underlying device has an IPv4
    /// address (skips serial/USB gadgets and other dead services).
    private static func firstActiveService() -> String? {
        guard let output = run(["-listnetworkserviceorder"]) else { return nil }
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for (i, line) in lines.enumerated() {
            guard let name = serviceName(from: line) else { continue }
            // The next line carries "(Hardware Port: ..., Device: enX)".
            guard i + 1 < lines.count,
                  let device = deviceName(from: lines[i + 1]) else { continue }
            if interfaceHasIPv4(device) { return name }
        }
        return nil
    }

    /// Extracts "enX" from a "(Hardware Port: ..., Device: enX)" line.
    private static func deviceName(from line: String) -> String? {
        guard let range = line.range(of: "Device: ") else { return nil }
        let rest = line[range.upperBound...]
        return rest.prefix { $0 != ")" && $0 != "," }.trimmingCharacters(in: .whitespaces)
    }

    /// True if the BSD interface currently has an IPv4 address assigned.
    private static func interfaceHasIPv4(_ device: String) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        proc.arguments = [device]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return false }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return false }
        return text.contains("inet ")
    }

    @discardableResult
    static func enable(socksPort: Int, httpPort: Int, host: String = "127.0.0.1") -> Bool {
        guard let service = primaryService() else { return false }
        var ok = true
        ok = run(["-setsocksfirewallproxy", service, host, String(socksPort)]) != nil && ok
        ok = run(["-setsocksfirewallproxystate", service, "on"]) != nil && ok
        ok = run(["-setwebproxy", service, host, String(httpPort)]) != nil && ok
        ok = run(["-setwebproxystate", service, "on"]) != nil && ok
        ok = run(["-setsecurewebproxy", service, host, String(httpPort)]) != nil && ok
        ok = run(["-setsecurewebproxystate", service, "on"]) != nil && ok
        return ok
    }

    @discardableResult
    static func disable() -> Bool {
        guard let service = primaryService() else { return false }
        run(["-setsocksfirewallproxystate", service, "off"])
        run(["-setwebproxystate", service, "off"])
        run(["-setsecurewebproxystate", service, "off"])
        return true
    }

    // MARK: - Helpers

    @discardableResult
    private static func run(_ args: [String]) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
