// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ARINC633Kit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        // Core ARINC 633-4 parsing kit.
        .library(name: "ARINC633Kit", targets: ["ARINC633Kit"]),
        // Optional Lido/vendor SUPP extension (AdditionalRemarks), NOT part of core.
        .library(name: "ARINC633KitSUPP", targets: ["ARINC633KitSUPP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "ARINC633Kit",
            dependencies: ["ZIPFoundation"],
            path: "Sources/ARINC633Kit"
        ),
        .target(
            name: "ARINC633KitSUPP",
            dependencies: ["ARINC633Kit"],
            path: "Sources/ARINC633KitSUPP"
        ),
        .testTarget(
            name: "ARINC633KitTests",
            dependencies: ["ARINC633Kit", "ARINC633KitSUPP", "ZIPFoundation"],
            path: "Tests/ARINC633KitTests",
            resources: [
                .copy("TestData")
            ]
        ),
    ]
)
