<p>
  <img src="docs/icon.png" width="128" alt="Beacon icon">
</p>

<h1>Beacon</h1>

<p>Beacon is a native macOS VPN client for the Xray-core and sing-box proxy engines. It is a fork of <a href="https://github.com/faustyu1/veil">faustyu1/veil</a> and brings a modern SwiftUI interface to V2Box and V2rayN-style clients.</p>

<p>Beacon works on macOS Sonoma 14 or higher.</p>

## Contents

- [Features](#features)
- [Install](#install-from-a-release)
- [Build from source](#build-from-source)
- [Usage](#usage)
- [Acknowledgements](#acknowledgements)

## Features

- Support for Xray-core (VLESS, VMess, Trojan, Shadowsocks) and sing-box (Hysteria2, TUIC, WireGuard, AnyTLS)
- Reality & TLS, XTLS Vision flow, VLESS encryption
- System Proxy and TUN (all traffic) modes
- Subscription and QR code import/export
- Menu-bar window
- Latency testing

## Install (from a release)

1. Download `Beacon.app.zip` from the [Releases](../../releases) page.
2. Unzip and move **Beacon.app** to `/Applications`.
3. **Important**: the app is not notarized. If MacOS gives a warning about not being able to open the app, navigate to Settings > Privacy & Security and press "Open Anyways." If Gatekeeper still blocks it, run `xattr -cr /Applications/Beacon.app` to clear the quarantine flag.

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

Note that a plain `swift run` will not show a window. MacOS needs the `.app` bundle that `run-app.sh` assembles.

### Tests

```bash
swift test
```

## Usage

- Add servers with a subscription URL or by pasting share links. You can also import from a QR code.
- Pick between proxy and TUN mode, which routes your traffic through only the browser or through all apps respectively.
- Click a server to select it or switch. The connect button and menu bar item act on the currently selected server.
- Set routing under Settings > Routing > Configure. Choose a preset or build your own rules.

## Acknowledgements

- [faustyu1/veil](https://github.com/faustyu1/veil) for the SwiftUI xray-core and singbox implementation
- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) and [SagerNet/sing-box](https://github.com/SagerNet/sing-box) for the proxy engines
- [xjasonlyu/tun2socks](https://github.com/xjasonlyu/tun2socks) for TUN to SOCKS
- Rule databases: [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat), [runetfreedom/russia-v2ray-rules-dat](https://github.com/runetfreedom/russia-v2ray-rules-dat), [v2fly](https://github.com/v2fly)
