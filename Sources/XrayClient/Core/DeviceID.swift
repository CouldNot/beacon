import Foundation

/// Generates a stable hardware identifier (HWID) from the macOS platform UUID.
/// Some subscription providers require this to identify the device.
enum DeviceID {

    /// Cached HWID — computed once on first access.
    static let hwid: String = generate()

    /// Reads `IOPlatformUUID` via `ioreg` and returns it.
    /// Falls back to a random UUID if the value cannot be obtained.
    private static func generate() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-d2", "-c", "IOPlatformExpertDevice"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                                encoding: .utf8) ?? ""
            // ioreg prints: "IOPlatformUUID" = "XXXX-XXXX-XXXX"
            // Find the UUID value after the `= "` separator.
            if let range = output.range(of: "IOPlatformUUID") {
                let rest = output[range.upperBound...]
                if let eqRange = rest.range(of: "= \"") {
                    let afterEq = rest[eqRange.upperBound...]
                    if let closeQ = afterEq.firstIndex(of: "\"") {
                        return String(afterEq[..<closeQ])
                    }
                }
            }
        } catch {}
        return UUID().uuidString
    }
}
