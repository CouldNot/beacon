import SwiftUI
import AppKit

/// Content shown in the menu bar dropdown: status, quick server switch,
/// connect/disconnect, and quit.
struct MenuBarContent: View {
    @Environment(ServerStore.self) private var store
    @Environment(ConnectionManager.self) private var connection
    @Environment(Loc.self) private var loc
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let selected = store.server(withID: store.selectedServerID)

        // Primary action button first, then the server/location as a label.
        if connection.isConnected {
            Button(loc("Disconnect")) { connection.disconnect() }
            Text(connection.activeServerName)
            Divider()
        } else if connection.state == .connecting {
            Button(loc("Disconnect")) { connection.disconnect() }
            Text(loc("Connecting…"))
            Divider()
        } else {
            if let selected {
                Button(loc("Connect")) { connection.connect(to: selected) }
                Text(selected.name)
            } else {
                Text(loc("Select a server"))
            }
            Divider()
        }

        // Quick switch: list servers grouped by subscription.
        ForEach(store.subscriptions) { sub in
            if !sub.servers.isEmpty {
                Menu(sub.name) {
                    ForEach(sub.servers) { server in
                        Button {
                            store.select(server.id)
                            connection.connect(to: server)
                        } label: {
                            if connection.activeServerID == server.id {
                                Label(server.name, systemImage: "checkmark")
                            } else {
                                Text(server.name)
                            }
                        }
                    }
                }
            }
        }

        Divider()
        Button(loc("Open Window")) {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
            // Bring the (possibly recreated) window to the front.
            DispatchQueue.main.async {
                for window in NSApp.windows where window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        Button(loc("Quit Beacon")) {
            connection.disconnect()
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
