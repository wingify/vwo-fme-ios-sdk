// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VWO-FME",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "VWO-FME",
            targets: ["VWO-FME"]),
    ],
    dependencies: [
        // Add any dependencies here, if needed.
    ],
    targets: [
        .target(
            name: "VWO-FME",
            dependencies: [],
            path: "VWO-FME",
            exclude: [],
            resources: [
                .process("Resources")
            ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("VWO-FME")
            ]
        ),
	    .testTarget(
            name: "VWO-FMETests",
            dependencies: ["VWO-FME"],
            path: "VWO-FMETests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
