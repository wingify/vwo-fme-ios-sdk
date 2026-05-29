// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    // Package identity used when referencing this repo from another Package.swift
    // (e.g. .package(url: "...", from: "1.18.0") + package: "vwo-fme-ios-sdk")
    name: "Wingify-FME",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12),
        .macOS(.v10_14),
        .watchOS(.v7)
    ],
    products: [
        // Recommended for new integrations
        .library(
            name: "Wingify-FME",
            targets: ["Wingify-FME"]
        ),
        // Legacy VWO-branded product (thin re-export of Wingify-FME)
        .library(
            name: "VWO-FME",
            targets: ["VWO-FME"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Wingify-FME",
            dependencies: [],
            path: "Wingify-FME",
            resources: [
                .process("Resources"),
                .process("CoreData/Model/OffineEventData.xcdatamodeld")
            ],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        ),
        .target(
            name: "VWO-FME",
            dependencies: ["Wingify-FME"],
            path: "VWO-FME"
        ),
        .testTarget(
            name: "Wingify-FMETests",
            dependencies: ["Wingify-FME"],
            path: "Wingify-FMETests",
            resources: [
                .copy("SettingsJson"),
                .copy("GetFlag"),
                .copy("SegmentEvaluator"),
                .copy("Utility/TestJson")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
