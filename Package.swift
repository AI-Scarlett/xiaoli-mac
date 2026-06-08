// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Xiaoli",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Xiaoli", targets: ["Xiaoli"])
    ],
    targets: [
        .executableTarget(
            name: "Xiaoli",
            path: "Sources/Xiaoli",
            linkerSettings: [
                .linkedFramework("ServiceManagement"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
