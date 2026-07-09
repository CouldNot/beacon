<p align="center">
  <img src="docs/icon.png" width="128" alt="Beacon icon">
</p>

<h1 align="center">Beacon</h1>

<p align="center">A native macOS VPN client for the Xray-core and sing-box proxy engines, built with SwiftUI.</p>

Beacon brings a Happ / v2RayTun-style experience to the Mac: subscription profiles, one-click connect, full-traffic tunneling, and professional domain/IP routing, all in a clean menu-bar app.

> **Fork.** Beacon is a fork of [faustyu1/veil](https://github.com/faustyu1/veil).

> **Disclaimer.** Beacon is a client for proxy protocols intended for privacy, development, and lawful circumvention of censorship. You are responsible for complying with the laws and terms of service that apply to you. The bundled cores ([Xray-core](https://github.com/XTLS/Xray-core), [sing-box](https://github.com/SagerNet/sing-box), [tun2socks](https://github.com/xjasonlyu/tun2socks)) are third-party software under their own licenses.

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Install](#install-from-a-release)
- [Build from source](#build-from-source)
- [Usage](#usage)
- [Acknowledgements](#acknowledgements)
- [License](#license)

## Features

- Two cores: Xray-core (VLESS, VMess, Trojan, Shadowsocks) and sing-box (Hysteria2, TUIC, WireGuard, AnyTLS)
- Reality & TLS, XTLS Vision flow, VLESS post-quantum encryption
- System Proxy mode, no admin password
- TUN mode routes every app, no password after first setup
- Subscription import with traffic, expiry, and title headers
- QR code export and import (image or camera)
- v2rayN-style geo routing with presets and a full rule editor
- One-tap ad & tracker blocking
- Sub-second server switching with no password prompt
- Per-server and per-group latency testing
- Menu-bar connect, disconnect, and quick-switch
- Launch at login and connect/disconnect notifications
- Localized in 12 languages
- Safe shutdown that restores routes and DNS

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel
- Swift 6 toolchain (Xcode 16+) to build from source

## Install (from a release)

1. Download `Beacon.app.zip` from the [Releases](../../releases) page.
2. Unzip and move **Beacon.app** to `/Applications`.
3. The app is ad-hoc signed. On first launch, right-click → **Open**, or allow it under **System Settings → Privacy & Security**.

## Build from source

```bash
git clone <your-repo-url> beacon
cd beacon

# Fetch the bundled cores (architecture detected automatically)
Scripts/fetch-xray.sh
Scripts/fetch-singbox.sh
Scripts/fetch-tun2socks.sh

# Optional: regenerate the app icon
Scripts/make-icon.sh

# Build, package into Beacon.app, and launch
Scripts/run-app.sh release
```

> A plain `swift run` will not show a window - macOS needs the `.app` bundle that `run-app.sh` assembles (Info.plist, icon, ad-hoc codesign).

### Tests

```bash
swift test
```

## Usage

Add servers with a subscription URL or by pasting share links. You can also import from a QR code.

Pick a mode. Proxy covers browsers. TUN covers every app and asks for your password once on first use.

Click a server to connect or switch. The connect button and menu-bar item act on the last server you picked.

Set routing under Settings, Routing, Configure. Choose a preset or build your own rules.

## Acknowledgements

- [faustyu1/veil](https://github.com/faustyu1/veil) - the project Beacon is forked from
- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) - VLESS/VMess/Trojan/SS proxy engine
- [SagerNet/sing-box](https://github.com/SagerNet/sing-box) - Hysteria2/TUIC/WireGuard/AnyTLS engine
- [xjasonlyu/tun2socks](https://github.com/xjasonlyu/tun2socks) - TUN to SOCKS
- Rule databases: [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat), [runetfreedom/russia-v2ray-rules-dat](https://github.com/runetfreedom/russia-v2ray-rules-dat), [v2fly](https://github.com/v2fly)

## License

MIT - see [LICENSE](LICENSE).
