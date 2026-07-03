import Foundation

/// Safe replacement for the SPM-synthesized `Bundle.module`.
///
/// `Bundle.module` is a `static let` whose initializer calls `fatalError(…)`
/// when the `Beacon_Beacon.bundle` resource bundle can't be located —
/// so *merely accessing it* hard-crashes the app (e.g. when the .app is run
/// from a copy/volume where the resource bundle didn't come along). This finder
/// performs the same candidate search but returns `nil` instead of trapping.
enum ResourceBundle {
    private final class BundleFinder {}

    static let module: Bundle? = {
        let bundleName = "Beacon_Beacon"

        var candidates = [
            Bundle.main.resourceURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle.main.bundleURL,
        ]

        // Bundle next to the running executable (handy for `swift run`).
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        candidates.append(exeDir)
        candidates.append(exeDir.deletingLastPathComponent())

        for candidate in candidates {
            let url = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let url, let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()
}

/// Locates a bundled (or system) core executable by name.
enum CoreBinary {
    /// Finds an executable named `name` (e.g. "xray" or "sing-box").
    static func locate(_ name: String) -> URL? {
        // 1. SPM resource bundle — where `.copy("Resources/…")` lands.
        if let resourceURL = ResourceBundle.module?.url(forResource: name, withExtension: nil) {
            return resourceURL
        }
        // 2. Main bundle (in case resources are flattened into the app bundle).
        if let resourceURL = Bundle.main.url(forResource: name, withExtension: nil) {
            return resourceURL
        }
        // 3. Next to the running binary (handy for `swift run`).
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        let sibling = exeDir.appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: sibling.path) {
            return sibling
        }
        // 4. A few common install locations / PATH fallbacks.
        for dir in ["/usr/local/bin", "/opt/homebrew/bin"] {
            let candidate = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }

    /// Resolves the executable for a given core engine.
    static func locate(for engine: CoreEngine) -> URL? {
        switch engine {
        case .xray:    return locate("xray")
        case .singbox: return locate("sing-box")
        }
    }
}

/// Locates the bundled (or system) `xray` executable.
enum XrayBinary {
    static func locate() -> URL? { CoreBinary.locate("xray") }
}

/// Manages the lifecycle of the `xray` core subprocess and streams its logs.
final class XrayProcess {
    private var process: Process?
    private let queue = DispatchQueue(label: "xray.process")

    /// Called on the main queue with each new log line.
    var onLog: (@Sendable (String) -> Void)?
    /// Called on the main queue when the process exits unexpectedly.
    var onExit: (@Sendable (Int32) -> Void)?

    var isRunning: Bool { process?.isRunning ?? false }

    /// Writes the config to a temp file and launches xray with `run -c`.
    /// `assetDir` is exported as `XRAY_LOCATION_ASSET` so geosite:/geoip: rules
    /// can find geoip.dat / geosite.dat.
    func start(configData: Data, binary: URL, assetDir: URL? = nil) throws {
        stop()

        let tmpDir = FileManager.default.temporaryDirectory
        let configURL = tmpDir.appendingPathComponent("xray-config-\(UUID().uuidString).json")
        try configData.write(to: configURL)

        let proc = Process()
        proc.executableURL = binary
        proc.arguments = ["run", "-c", configURL.path]
        if let assetDir {
            var env = ProcessInfo.processInfo.environment
            env["XRAY_LOCATION_ASSET"] = assetDir.path
            proc.environment = env
        }

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        let logCallback = onLog
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { logCallback?(text) }
        }

        let exitCallback = onExit
        proc.terminationHandler = { p in
            pipe.fileHandleForReading.readabilityHandler = nil
            try? FileManager.default.removeItem(at: configURL)
            let status = p.terminationStatus
            DispatchQueue.main.async { exitCallback?(status) }
        }

        try proc.run()
        self.process = proc
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            process = nil
            return
        }
        proc.terminationHandler = nil
        proc.terminate()
        process = nil
    }
}
