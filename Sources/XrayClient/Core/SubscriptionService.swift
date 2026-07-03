import Foundation

/// Refreshes subscription profiles from their URLs.
@MainActor
enum SubscriptionService {

    /// Refresh a single subscription by URL and write results into the store.
    @discardableResult
    static func refresh(_ sub: Subscription, into store: ServerStore) async -> Bool {
        guard let url = sub.url else { return false }
        let hwid = store.settings.sendHwid ? DeviceID.hwid : nil
        do {
            let result = try await SubscriptionFetcher.fetch(url, hwid: hwid)
            guard !result.servers.isEmpty else { return false }
            let name = result.profileTitle ?? sub.name
            store.addOrUpdateSubscription(name: name, url: url,
                                          servers: result.servers,
                                          userinfo: result.userinfo,
                                          announce: result.announce)
            return true
        } catch {
            return false
        }
    }

    /// Refresh all subscriptions that have auto-update enabled and are stale.
    static func refreshDue(_ store: ServerStore) async {
        guard store.settings.autoUpdateSubscriptions else { return }
        let interval = TimeInterval(store.settings.autoUpdateIntervalHours * 3600)
        let now = Date()
        for sub in store.subscriptions where sub.autoUpdate && !sub.isManual {
            let due = sub.lastUpdated.map { now.timeIntervalSince($0) >= interval } ?? true
            if due { await refresh(sub, into: store) }
        }
    }

    /// Refresh every subscription regardless of staleness (manual "refresh all").
    static func refreshAll(_ store: ServerStore) async {
        for sub in store.subscriptions where !sub.isManual {
            await refresh(sub, into: store)
        }
    }
}
