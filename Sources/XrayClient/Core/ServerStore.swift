import Foundation
import Observation

/// Holds subscription profiles, the selected server, and app settings.
/// Persists everything to JSON in Application Support.
@MainActor
@Observable
final class ServerStore {
    private(set) var subscriptions: [Subscription] = []
    var settings = AppSettings()
    var selectedServerID: UUID?

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Beacon", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("store.json")
        load()
        selectedServerID = settings.lastSelectedServerID
    }

    // MARK: - Derived

    /// All servers across every subscription, flattened.
    var allServers: [ProxyConfig] {
        subscriptions.flatMap(\.servers)
    }

    func server(withID id: UUID?) -> ProxyConfig? {
        guard let id else { return nil }
        return allServers.first { $0.id == id }
    }

    func subscriptionContaining(serverID: UUID?) -> Subscription? {
        guard let id = serverID else { return nil }
        return subscriptions.first { $0.servers.contains(where: { $0.id == id }) }
    }

    // MARK: - Manual servers

    private func ensureManualGroup() -> Int {
        if let idx = subscriptions.firstIndex(where: { $0.isManual }) { return idx }
        subscriptions.insert(Subscription(name: "Manual"), at: 0)
        return 0
    }

    func addManualServers(_ servers: [ProxyConfig]) {
        let idx = ensureManualGroup()
        subscriptions[idx].servers.append(contentsOf: servers)
        save()
    }

    /// Removes specific servers (by id) from any subscription group. Empties the
    /// Manual group if it becomes empty.
    func removeServers(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for i in subscriptions.indices {
            subscriptions[i].servers.removeAll { ids.contains($0.id) }
        }
        // Drop an emptied Manual group to keep the list tidy.
        subscriptions.removeAll { $0.isManual && $0.servers.isEmpty }
        if let sel = selectedServerID, !ids.contains(sel) {} else { selectedServerID = nil }
        save()
    }

    /// Removes a single server by id.
    func removeServer(id: UUID) {
        removeServers(ids: [id])
    }

    // MARK: - Subscriptions

    func addOrUpdateSubscription(name: String, url: String,
                                 servers: [ProxyConfig],
                                 userinfo: SubscriptionUserinfo.Info?,
                                 announce: String? = nil) {
        let idx = subscriptions.firstIndex { $0.url == url }
        if let idx {
            // Preserve UI state and identity, refresh the contents.
            subscriptions[idx].name = name
            subscriptions[idx].servers = servers
            subscriptions[idx].lastUpdated = Date()
            if let announce { subscriptions[idx].note = announce }
            applyUserinfo(userinfo, to: idx)
        } else {
            var sub = Subscription(name: name, url: url)
            sub.servers = servers
            sub.lastUpdated = Date()
            sub.note = announce
            subscriptions.append(sub)
            applyUserinfo(userinfo, to: subscriptions.count - 1)
        }
        save()
    }

    private func applyUserinfo(_ info: SubscriptionUserinfo.Info?, to idx: Int) {
        guard let info else { return }
        subscriptions[idx].uploadBytes = info.upload
        subscriptions[idx].downloadBytes = info.download
        subscriptions[idx].totalBytes = info.total
        subscriptions[idx].expiresAt = info.expire
    }

    func removeSubscription(id: UUID) {
        subscriptions.removeAll { $0.id == id }
        save()
    }

    func toggleCollapsed(id: UUID) {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[idx].isCollapsed.toggle()
        save()
    }

    func setAutoUpdate(_ on: Bool, id: UUID) {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[idx].autoUpdate = on
        save()
    }

    func setNote(_ note: String, id: UUID) {
        guard let idx = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions[idx].note = note.isEmpty ? nil : note
        save()
    }

    func select(_ serverID: UUID) {
        selectedServerID = serverID
        settings.lastSelectedServerID = serverID
        save()
    }

    // MARK: - Disk

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
            subscriptions = decoded.subscriptions
            settings = decoded.settings ?? AppSettings()
        }
    }

    func save() {
        let payload = Persisted(subscriptions: subscriptions, settings: settings)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL)
        }
    }

    private struct Persisted: Codable {
        var subscriptions: [Subscription]
        var settings: AppSettings?
    }
}
