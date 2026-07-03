import Foundation
import Observation

/// Downloads and stores the geoip.dat / geosite.dat rule databases that Xray
/// needs to resolve `geosite:` and `geoip:` routing matchers. Files live in
/// Application Support/XrayClient/geo/ and Xray is pointed there via the
/// `XRAY_LOCATION_ASSET` environment variable.
@MainActor
@Observable
final class GeoAssetManager {
    static let shared = GeoAssetManager()

    private(set) var isDownloading = false
    private(set) var lastError: String?
    private(set) var lastUpdated: Date?

    let directory: URL

    private let geoipName = "geoip.dat"
    private let geositeName = "geosite.dat"

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Beacon/geo", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.directory = dir
        refreshState()
    }

    var geoipURL: URL { directory.appendingPathComponent(geoipName) }
    var geositeURL: URL { directory.appendingPathComponent(geositeName) }

    /// True when both .dat files are present on disk.
    var hasAssets: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: geoipURL.path)
            && fm.fileExists(atPath: geositeURL.path)
    }

    private func refreshState() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: geoipURL.path)
        lastUpdated = attrs?[.modificationDate] as? Date
    }

    /// Downloads both .dat files from the given source. Throws on failure.
    func download(source: GeoAssetSource,
                  customGeoip: String = "",
                  customGeosite: String = "") async {
        guard !isDownloading else { return }
        isDownloading = true
        lastError = nil
        defer { isDownloading = false }

        let geoip = source.geoipURL(custom: customGeoip)
        let geosite = source == .custom ? customGeosite
                                        : source.geositeURL(custom: customGeosite)

        do {
            try await fetch(urlString: geoip, to: geoipURL)
            try await fetch(urlString: geosite, to: geositeURL)
            refreshState()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Downloads one file to a temp location then atomically replaces the target.
    private func fetch(urlString: String, to destination: URL) async throws {
        guard let url = URL(string: urlString), url.scheme == "https" else {
            throw AssetError.badURL(urlString)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AssetError.httpStatus(urlString)
        }
        let fm = FileManager.default
        // Sanity check: .dat files are well over 1 KB; reject error pages.
        let size = (try? fm.attributesOfItem(atPath: tempURL.path)[.size] as? Int) ?? 0
        if (size ?? 0) < 1024 { throw AssetError.tooSmall(urlString) }
        if fm.fileExists(atPath: destination.path) {
            _ = try fm.replaceItemAt(destination, withItemAt: tempURL)
        } else {
            try fm.moveItem(at: tempURL, to: destination)
        }
    }

    enum AssetError: LocalizedError {
        case badURL(String)
        case httpStatus(String)
        case tooSmall(String)

        var errorDescription: String? {
            switch self {
            case .badURL(let u):    return "Invalid URL: \(u)"
            case .httpStatus(let u): return "Download failed: \(u)"
            case .tooSmall(let u):  return "File too small (not a .dat): \(u)"
            }
        }
    }
}
