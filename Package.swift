// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SwiftRex",
    platforms: [.macOS(.v10_10), .iOS(.v9), .tvOS(.v9), .watchOS(.v3)],
    products: [
        .library(name: "CombineRex", targets: ["SwiftRex", "CombineRex"]),
        .library(name: "ReactiveSwiftRex", targets: ["SwiftRex", "ReactiveSwiftRex"]),
        .library(name: "RxSwiftRex", targets: ["SwiftRex", "RxSwiftRex"]),

        .library(name: "CombineRexDynamic", type: .dynamic, targets: ["SwiftRex", "CombineRex"]),
        .library(name: "ReactiveSwiftRexDynamic", type: .dynamic, targets: ["SwiftRex", "ReactiveSwiftRex"]),
        .library(name: "RxSwiftRexDynamic", type: .dynamic, targets: ["SwiftRex", "RxSwiftRex"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.2.0"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "SwiftRex",
            exclude: ["CodeGeneration/Templates"]
        ),
        .target(name: "CombineRex", dependencies: ["SwiftRex"]),
        .target(name: "ReactiveSwiftRex", dependencies: ["SwiftRex", "ReactiveSwift"]),
        .target(name: "RxSwiftRex", dependencies: ["SwiftRex", "RxSwift"]),

        .testTarget(name: "SwiftRexTests", dependencies: ["SwiftRex"]),
        .testTarget(name: "CombineRexTests", dependencies: ["CombineRex"]),
        .testTarget(name: "ReactiveSwiftRexTests", dependencies: ["ReactiveSwiftRex"]),
        .testTarget(name: "RxSwiftRexTests", dependencies: ["RxSwiftRex"]),

        .testTarget(
            name: "SwiftRexDeprecationTests",
            dependencies: ["SwiftRex"],
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        ),
        .testTarget(
            name: "CombineRexDeprecationTests",
            dependencies: ["CombineRex"],
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        ),
        .testTarget(
            name: "ReactiveSwiftRexDeprecationTests",
            dependencies: ["ReactiveSwiftRex"],
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        ),
        .testTarget(
            name: "RxSwiftRexDeprecationTests",
            dependencies: ["RxSwiftRex"],
            swiftSettings: [.unsafeFlags(["-suppress-warnings"])]
        )
    ],
    swiftLanguageVersions: [.v5]
)
