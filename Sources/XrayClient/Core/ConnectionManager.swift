import Foundation
import Observation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting…"
        case .connected:    return "Connected"
        case .failed(let m): return "Failed: \(m)"
        }
    }
}

/// Top-level coordinator: owns the xray process, the active transport mode
/// (system proxy or TUN), uptime tracking, and logs.
@MainActor
@Observable
final class ConnectionManager {
    private(set) var state: ConnectionState = .disconnected
    private(set) var activeServerID: UUID?
    private(set) var activeServerName: String = ""
    private(set) var logs: String = ""
    private(set) var connectedSince: Date?
    private(set) var uptimeText: String = ""

    var mode: TunnelMode = .systemProxy
    var ports = InboundPorts()
    /// The ordered routing rules to apply on the next (re)connect.
    var routingRules: [RoutingRule] = []
    /// Xray core log verbosity.
    var logLevel: LogLevel = .warning

    /// Auto-reconnect when the link silently dies (NAT/firewall idle timeout).
    var autoReconnect: Bool = true

    /// Post a macOS notification on connect / disconnect / reconnect events.
    var notifyOnConnect: Bool = false

    private let xray = XrayProcess()
    private var activeMode: TunnelMode = .systemProxy
    private var uptimeTimer: Timer?

    /// The server we're currently connected to, kept so the watchdog can
    /// transparently restart the tunnel without user input.
    private var activeServer: ProxyConfig?
    private var watchdogTask: Task<Void, Never>?
    /// True while a watchdog-driven reconnect is in flight, so the UI doesn't
    /// flicker through .connecting and the uptime clock isn't reset.
    private var isReconnecting = false

    init() {
        xray.onLog = { [weak self] line in
            Task { @MainActor in self?.appendLog(line) }
        }
        xray.onExit = { [weak self] code in
            Task { @MainActor in
                guard let self else { return }
                // Ignore exits we triggered ourselves (stop/restart).
                guard self.state == .connected || self.state == .connecting else { return }
                if self.autoReconnect, self.activeServer != nil {
                    self.appendLog("[warn] xray exited (code \(code)) — reconnecting\n")
                    self.reconnect()
                } else {
                    self.teardownTransport()
                    self.state = .failed("xray exited (code \(code))")
                    self.stopUptime()
                }
            }
        }
    }

    var isConnected: Bool { state == .connected }

    /// Connect to a server. If already connected, switches by restarting only
    /// xray and re-pinning the route — the transport (TUN/proxy) stays up, so a
    /// switch is sub-second and never re-prompts for a password.
    func connect(to server: ProxyConfig) {
        let wasConnected = (state == .connected || state == .connecting)
        let keepTransport = wasConnected && (activeMode == mode)

        activeServer = server
        if wasConnected && !keepTransport {
            // Mode actually changed → full teardown.
            teardownTransport()
        }
        xray.stop()

        guard let binary = CoreBinary.locate(for: server.engine) else {
            let missing = server.engine == .singbox ? "sing-box" : "xray"
            let script = server.engine == .singbox ? "fetch-singbox.sh" : "fetch-xray.sh"
            fail("\(missing) binary not found. Run Scripts/\(script)")
            return
        }
        state = .connecting
        if !isReconnecting { logs = "" }
        activeServerName = server.name
        let coreName = server.engine == .singbox ? "sing-box" : "xray"
        appendLog("[info] \(keepTransport ? "switching to" : "starting") \(server.name) (\(mode.title), \(coreName))\n")

        do {
            let data: Data
            switch server.engine {
            case .xray:
                data = try XrayConfigBuilder.jsonData(for: server, ports: ports,
                                                      rules: routingRules,
                                                      logLevel: logLevel.rawValue)
            case .singbox:
                data = try SingBoxConfigBuilder.jsonData(for: server, ports: ports,
                                                         rules: routingRules,
                                                         logLevel: logLevel.rawValue)
            }
            // Point the core at the geo .dat dir only when Xray rules reference
            // geosite/geoip (sing-box doesn't use this env).
            let needsGeo = server.engine == .xray && routingRules.contains { rule in
                rule.domains.contains { $0.hasPrefix("geosite:") }
                    || rule.ips.contains { $0.hasPrefix("geoip:") }
            }
            let assetDir = needsGeo ? GeoAssetManager.shared.directory : nil
            try xray.start(configData: data, binary: binary, assetDir: assetDir)
        } catch {
            fail(error.localizedDescription)
            return
        }

        let chosenMode = mode
        let socksAddr = "\(ports.listen):\(ports.socks)"
        let serverHost = server.address
        let socksHost = ports.listen
        let socksPort = ports.socks

        // Poll the SOCKS inbound until it accepts connections, then bring up the
        // transport immediately — much faster than a fixed delay.
        Task.detached(priority: .userInitiated) {
            let ready = await ConnectionManager.waitForPort(host: socksHost,
                                                            port: socksPort,
                                                            timeout: 2.0)
            await MainActor.run {
                guard self.state == .connecting else { return }
                guard self.xray.isRunning else { return } // onExit reports failure
                guard ready else {
                    self.xray.stop()
                    self.fail("xray did not start listening")
                    return
                }
                self.bringUpTransport(mode: chosenMode,
                                      socksAddr: socksAddr,
                                      serverHost: serverHost,
                                      serverID: server.id,
                                      keepTransport: keepTransport)
            }
        }
    }

    /// Polls a TCP port until connectable or the timeout elapses.
    private nonisolated static func waitForPort(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await PingTester.tcpLatency(host: host, port: port, timeout: 0.3) != nil {
                return true
            }
            try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
        }
        return false
    }

    private func bringUpTransport(mode: TunnelMode, socksAddr: String,
                                  serverHost: String, serverID: UUID,
                                  keepTransport: Bool) {
        switch mode {
        case .systemProxy:
            // The system proxy points at the same SOCKS port, so when we're just
            // switching servers it's already active — nothing to do.
            if keepTransport {
                finishConnect(serverID: serverID, mode: mode)
                return
            }
            let ok = SystemProxy.enable(socksPort: ports.socks, httpPort: ports.http)
            if ok {
                finishConnect(serverID: serverID, mode: mode)
                appendLog("[info] system proxy enabled\n")
            } else {
                xray.stop()
                fail("could not set system proxy")
            }
        case .tun:
            // tun2socks keeps running across switches; tun-up.sh fast-path just
            // re-pins the new server IP (sub-second, no utun re-create).
            Task.detached(priority: .userInitiated) {
                let ips = TunManager.resolveIPs(host: serverHost)
                do {
                    try TunManager.up(socksAddr: socksAddr, serverIPs: ips)
                    await MainActor.run {
                        self.finishConnect(serverID: serverID, mode: mode)
                        self.appendLog("[info] TUN \(keepTransport ? "re-pinned" : "up") (\(ips.joined(separator: ", ")))\n")
                    }
                } catch {
                    await MainActor.run {
                        self.xray.stop()
                        self.fail(error.localizedDescription)
                    }
                }
            }
        }
    }

    private func finishConnect(serverID: UUID, mode: TunnelMode) {
        let wasReconnecting = isReconnecting
        activeServerID = serverID
        activeMode = mode
        state = .connected
        isReconnecting = false
        if connectedSince == nil { startUptime() }
        startWatchdog()
        if notifyOnConnect {
            NotificationManager.notify(
                title: wasReconnecting ? "Reconnected" : "Connected",
                body: activeServerName)
        }
    }

    func disconnect() {
        let wasConnected = (state == .connected)
        let name = activeServerName
        stopWatchdog()
        activeServer = nil
        teardownTransport()
        xray.stop()
        activeServerID = nil
        state = .disconnected
        stopUptime()
        appendLog("[info] disconnected\n")
        if notifyOnConnect && wasConnected {
            NotificationManager.notify(title: "Disconnected", body: name)
        }
    }

    private func teardownTransport() {
        switch activeMode {
        case .systemProxy: SystemProxy.disable()
        case .tun:         TunManager.down()
        }
    }

    private func fail(_ message: String) {
        isReconnecting = false
        state = .failed(message)
        appendLog("[error] \(message)\n")
        stopUptime()
    }

    // MARK: - Watchdog / auto-reconnect

    /// Restarts the tunnel for the active server without tearing down the
    /// transport or resetting the uptime clock. Used by the watchdog and by the
    /// xray.onExit handler when the link dies unexpectedly.
    private func reconnect() {
        guard let server = activeServer else { return }
        isReconnecting = true
        // connect() keeps the transport up when the mode is unchanged, so this
        // just relaunches xray and re-pins the route — sub-second, no prompts.
        connect(to: server)
    }

    /// Periodically probes end-to-end connectivity through the SOCKS proxy and
    /// silently reconnects if the link has gone dead (e.g. NAT idle timeout,
    /// where xray stays alive but no traffic flows).
    private func startWatchdog() {
        watchdogTask?.cancel()
        guard autoReconnect else { return }
        let host = ports.listen
        let socksPort = ports.socks
        watchdogTask = Task { [weak self] in
            // Number of consecutive failed probes before forcing a reconnect.
            let maxFailures = 2
            var failures = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                if Task.isCancelled { return }
                guard let self else { return }
                // Only probe while we believe we're connected and idle.
                let busy = await MainActor.run { self.state != .connected || self.isReconnecting }
                if busy { failures = 0; continue }

                let alive = await HealthProbe.throughSocks(host: host, port: socksPort)
                if alive {
                    failures = 0
                    continue
                }
                failures += 1
                if failures >= maxFailures {
                    failures = 0
                    await MainActor.run {
                        guard self.state == .connected, !self.isReconnecting else { return }
                        self.appendLog("[warn] health check failed — reconnecting\n")
                        self.reconnect()
                    }
                }
            }
        }
    }

    private func stopWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    // MARK: - Uptime

    private func startUptime() {
        connectedSince = Date()
        uptimeText = "00:00"
        uptimeTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickUptime() }
        }
        RunLoop.main.add(timer, forMode: .common)
        uptimeTimer = timer
    }

    private func tickUptime() {
        guard let since = connectedSince else { return }
        let s = Int(Date().timeIntervalSince(since))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        uptimeText = h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    private func stopUptime() {
        uptimeTimer?.invalidate()
        uptimeTimer = nil
        connectedSince = nil
        uptimeText = ""
    }

    // MARK: - Logs

    /// Clears the in-memory log buffer (does not affect the running core).
    func clearLogs() { logs = "" }

    private func appendLog(_ text: String) {
        logs += text
        if logs.count > 20_000 {
            logs = String(logs.suffix(16_000))
        }
    }
}
