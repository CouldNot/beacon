import Foundation

/// Manages TUN (full-traffic) mode using `tun2socks` + route manipulation.
///
/// First use installs a small root-owned helper + a scoped NOPASSWD sudoers
/// rule (one admin prompt, ever). After that, bringing the tunnel up/down runs
/// via `sudo -n` with no password — so switching servers is seamless.
enum TunManager {

    static let installDir = "/usr/local/libexec/beacon"
    static let upPath = installDir + "/tun-up.sh"
    static let downPath = installDir + "/tun-down.sh"
    static let pingPath = installDir + "/tun-ping.sh"

    enum TunError: LocalizedError {
        case missingResource(String)
        case scriptFailed(String)
        case installFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingResource(let r): return "Missing bundled resource: \(r)"
            case .scriptFailed(let m):     return "TUN command failed: \(m)"
            case .installFailed(let m):    return "Helper install failed: \(m)"
            }
        }
    }

    // MARK: - Resource lookup

    private static func resource(_ name: String) -> URL? {
        if let url = ResourceBundle.module?.url(forResource: name, withExtension: nil) { return url }
        return Bundle.main.url(forResource: name, withExtension: nil)
    }

    /// Directory that holds the bundled tun2socks + scripts.
    private static func resourceDir() -> URL? {
        resource("tun2socks")?.deletingLastPathComponent()
    }

    // MARK: - Helper installation

    /// True if the privileged helper + sudoers rule are already installed AND
    /// up to date (contains the fast re-pin path + ping helper).
    static var isHelperInstalled: Bool {
        guard FileManager.default.isExecutableFile(atPath: upPath),
              FileManager.default.isExecutableFile(atPath: downPath),
              FileManager.default.isExecutableFile(atPath: pingPath),
              FileManager.default.fileExists(atPath: "/etc/sudoers.d/beacon") else {
            return false
        }
        // Outdated installs (pre fast-path) should be re-installed once.
        if let script = try? String(contentsOfFile: upPath, encoding: .utf8) {
            return script.contains("Fast path")
        }
        return false
    }

    /// Installs the helper. Shows ONE macOS admin password prompt.
    static func installHelper() throws {
        guard let dir = resourceDir() else { throw TunError.missingResource("tun2socks") }
        guard let installer = resource("install-helper.sh") else {
            throw TunError.missingResource("install-helper.sh")
        }
        chmodX(resource("tun2socks"))
        let cmd = shellQuote(["/bin/bash", installer.path, dir.path])
        do {
            try runAsAdmin(cmd)
        } catch {
            throw TunError.installFailed(error.localizedDescription)
        }
    }

    /// Removes the helper + sudoers rule (one admin prompt).
    static func uninstallHelper() {
        guard let uninstaller = resource("uninstall-helper.sh") else { return }
        let cmd = shellQuote(["/bin/bash", uninstaller.path])
        try? runAsAdmin(cmd)
    }

    // MARK: - Up / Down

    /// Brings TUN up. Installs the helper first if needed (one-time prompt),
    /// then runs passwordless via `sudo -n`.
    static func up(socksAddr: String, serverIPs: [String]) throws {
        if !isHelperInstalled {
            try installHelper()
        }
        let ips = serverIPs.joined(separator: ",")
        try runSudoNoPass([upPath, socksAddr, ips])
    }

    /// Tears TUN down (passwordless). Best-effort.
    static func down() {
        try? runSudoNoPass([downPath])
    }

    /// True if a tunnel appears to be active on the system (utun123 exists or a
    /// tun2socks pid file is present) — used to detect orphaned tunnels left by
    /// a crash or force-quit.
    static var looksActive: Bool {
        FileManager.default.fileExists(atPath: "/tmp/beacon-tun2socks.pid") ||
        FileManager.default.fileExists(atPath: "/tmp/beacon-tun.state")
    }

    /// Runs the down script unconditionally to clean up an orphaned tunnel.
    /// Safe to call even when nothing is up (down script is idempotent).
    static func emergencyCleanup() {
        guard isHelperInstalled, looksActive else { return }
        try? runSudoNoPass([downPath])
    }

    /// Temporarily route server IPs via the physical gateway so latency probes
    /// bypass the tunnel. Best-effort; no-op if the helper isn't installed.
    static func pingRouteAdd(_ ips: [String]) {
        guard isHelperInstalled, !ips.isEmpty else { return }
        try? runSudoNoPass([pingPath, "add", ips.joined(separator: ",")])
    }

    /// Removes the temporary ping host-routes.
    static func pingRouteDel() {
        guard isHelperInstalled else { return }
        try? runSudoNoPass([pingPath, "del", ""])
    }

    // MARK: - Server IP resolution

    /// Resolves a host to IPv4 addresses. IP literals pass through unchanged.
    static func resolveIPs(host: String) -> [String] {
        if host.allSatisfy({ $0.isNumber || $0 == "." }),
           host.split(separator: ".").count == 4 {
            return [host]
        }
        var results: [String] = []
        var hints = addrinfo(ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_STREAM,
                             ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil,
                             ai_addr: nil, ai_next: nil)
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &info) == 0 else { return results }
        defer { freeaddrinfo(info) }
        var ptr = info
        while let node = ptr {
            if let sa = node.pointee.ai_addr {
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                    var addr = sin.pointee.sin_addr
                    inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN))
                }
                let ip = String(cString: buf)
                if !ip.isEmpty, !results.contains(ip) { results.append(ip) }
            }
            ptr = node.pointee.ai_next
        }
        return results
    }

    // MARK: - Privileged execution

    /// Runs `sudo -n <argv>` (non-interactive; relies on the NOPASSWD rule).
    private static func runSudoNoPass(_ argv: [String]) throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        proc.arguments = ["-n"] + argv
        let errPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = Pipe()
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "exit \(proc.terminationStatus)"
            throw TunError.scriptFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Runs a command as root via AppleScript's admin prompt (password dialog).
    private static func runAsAdmin(_ shellCommand: String) throws {
        let escaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", appleScript]
        let errPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = Pipe()
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "exit \(proc.terminationStatus)"
            throw TunError.scriptFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func chmodX(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private static func shellQuote(_ args: [String]) -> String {
        args.map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
            .joined(separator: " ")
    }
}
