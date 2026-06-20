// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ARINC633Kit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ARINC633Kit", targets: ["ARINC633Kit"]),
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
        .testTarget(
            name: "ARINC633KitTests",
            dependencies: ["ARINC633Kit", "ZIPFoundation"],
            path: "Tests/ARINC633KitTests",
            resources: [
                .copy("TestData")
            ]
        ),
    ]
)
