// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ShotMate",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ShotMate", targets: ["ShotMate"])
    ],
    targets: [
        .executableTarget(
            name: "ShotMate",
            path: "ShotMate",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
