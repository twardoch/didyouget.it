// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DidYouGet",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "DidYouGet",
            targets: ["DidYouGet"])
    ],
    dependencies: [
        // Dependencies will be added here as needed
    ],
    targets: [
        .executableTarget(
            name: "DidYouGet",
            dependencies: [],
            path: "DidYouGet/DidYouGet",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DidYouGetTests",
            dependencies: ["DidYouGet"])
    ]
)