# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

Beacon is a native macOS VPN client (menu-bar app) for the Xray-core and sing-box proxy engines, built with SwiftUI. Requires macOS 14+ and Swift 6 / Xcode 16+. The package target is named `Beacon` but the source lives in `Sources/XrayClient/` (forked from a project called Veil).

## Commands

```bash
# Fetch bundled proxy engine binaries (required before first build)
Scripts/fetch-xray.sh
Scripts/fetch-singbox.sh
Scripts/fetch-tun2socks.sh

# Build and launch as a proper .app bundle (required — plain `swift run` won't show a window)
Scripts/run-app.sh          # release build (default)
Scripts/run-app.sh debug    # debug build

# Run tests
swift test

# Run a single test class or method
swift test --filter LinkParserTests
swift test --filter XrayConfigBuilderTests/testVLESSConfigStructure
```

> `swift run` alone does not work — the app requires an `.app` bundle with `Info.plist` and ad-hoc codesign. `run-app.sh` assembles and signs `Beacon.app` then opens it.

## Architecture

```
SwiftUI app
 ├── Xray-core subprocess     VLESS/VMess/Trojan/Shadowsocks — SOCKS+HTTP inbounds on 127.0.0.1
 ├── sing-box subprocess      Hysteria2/TUIC/WireGuard/AnyTLS — same SOCKS+HTTP inbounds
 ├── System Proxy mode        networksetup points the active interface at the SOCKS/HTTP ports
 └── TUN mode                 tun2socks utun + split-default routes; server IP pinned to gateway
```

### Core data flow

1. **`ServerStore`** (`Core/ServerStore.swift`) — `@Observable` store that owns `[Subscription]` and `AppSettings`. Persists everything to `~/Library/Application Support/Beacon/store.json`. The single source of truth for server lists and settings.

2. **`ConnectionManager`** (`Core/ConnectionManager.swift`) — `@Observable` coordinator that owns `XrayProcess` and orchestrates connect/disconnect/switch/reconnect. It calls the config builders, polls the SOCKS port for readiness, then brings up either `SystemProxy` or `TunManager`. A watchdog task probes connectivity every 30 s and silently reconnects on failure.

3. **`ProxyConfig`** (`Models/ProxyConfig.swift`) — canonical server struct parsed from share links and fed to config builders. Its `engine` computed property determines which core (`.xray` vs `.singbox`) handles a given protocol.

4. **Config builders** — `XrayConfigBuilder` and `SingBoxConfigBuilder` (both in `Core/`) each take a `ProxyConfig` + routing rules and produce a JSON `[String: Any]` dict (or `Data`) ready to pass to the subprocess.

5. **`LinkParser` / `LinkBuilder`** (`Core/`) — parse share-link URI schemes (`vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`, `tuic://`, `anytls://`, `wireguard://`) into `ProxyConfig`, and rebuild them. WireGuard `.conf` text is also supported via `parseWireGuardConf`.

### Protocol → core routing

| Protocol                           | Core      |
| ---------------------------------- | --------- |
| VLESS, VMess, Trojan, Shadowsocks  | Xray-core |
| Hysteria2, TUIC, WireGuard, AnyTLS | sing-box  |

The correct binary is chosen automatically based on `ProxyConfig.engine`.

### TUN mode / privileged helper

TUN mode copies helper shell scripts to a system path and adds a scoped `NOPASSWD` sudoers rule (one-time password prompt). Subsequent `tun-up.sh` / `tun-down.sh` calls run via `sudo -n`. `TunManager.emergencyCleanup()` is called on launch and quit to recover from a crashed session.

### Ping strategies

- TCP connect — VLESS, VMess, Trojan, Shadowsocks, AnyTLS
- QUIC handshake — Hysteria2, TUIC (no TCP listener)
- ICMP echo — WireGuard (no TCP or QUIC listener)

### Persistence

`ServerStore` serialises a `Persisted { subscriptions, settings }` struct to JSON. `AppSettings` uses a resilient decoder (all keys have fallbacks) so older `store.json` files load without errors.

### Localization

`Loc` / `LocalizationTable` implement an in-app runtime locale switcher (12 languages) without depending on the system locale. RTL support is wired through `\.layoutDirection` in the SwiftUI environment.

## Tests

Tests live in `Tests/XrayClientTests/ParserTests.swift` and cover:

- `LinkParserTests` — all URI schemes, round-trips, edge cases
- `XrayConfigBuilderTests` — Xray JSON structure for VLESS/xhttp/inbounds
- `SingBoxConfigBuilderTests` — sing-box JSON for Hysteria2/TUIC/AnyTLS/WireGuard
- `LinkBuilderTests` — parse→build→parse round-trips and ping strategy classification

## Design

This is supposed to be a high-quality, native MacOS client app. Its intended user base is very small, just the author and anyone who stumbles upon it. Optimize design for minimalism, cleanliness, and a native feeling design language. Visual references are Reeder (https://reederapp.com/) and Xcode. If possible, use default and provided Swift elements and design.

If you are given reference images, do not attempt to be pixel-perfect in matching. Instead, go off of the general structure and impression. Always use Apple Liquid Glass native elements when possible. Use natively supported SF Symbols and always stick to a default, Swift-supported look. The number one goal is to create a native-looking, polished app, as if Apple itself made it. For example, if there is a on/off toggle in the reference image, and you cannot create the exact shape or length with default liquid glass SwiftUI elements, do not complicate things. Simply use the native liquid glass toggle. Always simplify for UI, never complicate.

If it is a strictly design-focused task, do not attempt to write new technical features in order to match what is on the design. If so, prompt for further inquiry or simply skip it. For example, if there is a text in the reference image that shows the current data transfer size but there is no preexisting code that can easily display that, simply skip it for now unless the user specifically asked for a new technical feature.
