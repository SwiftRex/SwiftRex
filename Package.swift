// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "SwiftRex",
    platforms: [
        .macOS(SupportedPlatform.MacOSVersion.v10_15),
        .iOS(SupportedPlatform.IOSVersion.v13),
        .tvOS(SupportedPlatform.TVOSVersion.v13),
        .watchOS(SupportedPlatform.WatchOSVersion.v6)
    ],
    products: [
        .library(name: "CombineRex", targets: ["SwiftRex", "CombineRex"]),
        .library(name: "CombineRexDynamic", type: .dynamic, targets: ["SwiftRex", "CombineRex"])
    ],
    dependencies: [ ],
    targets: [
        .target(name: "SwiftRex", dependencies: []),
        .target(name: "CombineRex", dependencies: ["SwiftRex"])
    ],
    swiftLanguageVersions: [.v5]
)
