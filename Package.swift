// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ExternalControllerKit",
    products: [
        .library(name: "ExternalControllerKit", targets: ["ExternalControllerKit"]),
        .library(name: "ExternalControllerKitUI", targets: ["ExternalControllerKitUI"])
    ],
    targets: [
        .target(
            name: "ExternalControllerKit",
            path: "Sources/ExternalControllerKit"
        ),
        .target(
            name: "ExternalControllerKitUI",
            dependencies: ["ExternalControllerKit"],
            path: "Sources/ExternalControllerKitUI"
        ),
        .testTarget(
            name: "ExternalControllerKitTests",
            dependencies: ["ExternalControllerKit"],
            path: "Tests/ExternalControllerKitTests"
        ),
        .testTarget(
            name: "ExternalControllerKitUITests",
            dependencies: ["ExternalControllerKitUI", "ExternalControllerKit"],
            path: "Tests/ExternalControllerKitUITests"
        )
    ],
    platforms: [
        .iOS(.v15)
    ],
)
