// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SirenUA",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SirenUA",
            targets: ["SirenUA"]
        ),
    ],
    targets: [
        .target(
            name: "SirenUA",
            dependencies: [],
            path: ".",
            exclude: [
                "Package.swift",
                "Info.plist",
                "*.sh"
            ],
            sources: [
                "SirenUAApp.swift",
                "ContentViewV2.swift",
                "MapViewV2.swift",
                "AlertViewModelV2.swift",
                "AlertStatusCardV2.swift",
                "AlertRegionDetailView.swift",
                "NetworkManager.swift",
                "AlertRegion.swift",
                "ErrorView.swift",
                "CriticalAlertManager.swift"
            ]
        ),
    ]
)
