// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Beacon",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Beacon",
            path: "Sources/XrayClient",
            resources: [
                .copy("Resources/xray"),
                .copy("Resources/sing-box"),
                .copy("Resources/tun2socks"),
                .copy("Resources/tun-up.sh"),
                .copy("Resources/tun-down.sh"),
                .copy("Resources/tun-ping.sh"),
                .copy("Resources/install-helper.sh"),
                .copy("Resources/uninstall-helper.sh")
            ]
        ),
        .testTarget(
            name: "BeaconTests",
            dependencies: ["Beacon"],
            path: "Tests/XrayClientTests"
        )
    ]
)
