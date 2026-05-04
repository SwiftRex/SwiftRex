// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftRex",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "SwiftRex", targets: ["SwiftRex"]),
        .library(name: "SwiftRexOperators", targets: ["SwiftRexOperators"]),
        .library(name: "CombineRex", targets: ["CombineRex"]),
        .library(name: "RxSwiftRex", targets: ["RxSwiftRex"]),
        .library(name: "ReactiveSwiftRex", targets: ["ReactiveSwiftRex"])
    ],
    dependencies: [
        .package(url: "https://github.com/luizmb/FP.git", from: "1.4.0"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.10.0"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "7.2.0")
    ],
    targets: [
        // MARK: - Core

        .target(
            name: "SwiftRex",
            dependencies: [
                .product(name: "CoreFP", package: "FP"),
                .product(name: "DataStructure", package: "FP")
            ],
            path: "Sources/SwiftRex"
        ),

        // MARK: - Operators (optional, symbolic sugar)

        .target(
            name: "SwiftRexOperators",
            dependencies: [
                "SwiftRex",
                .product(name: "CoreFPOperators", package: "FP"),
                .product(name: "DataStructureOperators", package: "FP")
            ],
            path: "Sources/SwiftRexOperators"
        ),

        // MARK: - Bridges

        .target(
            name: "CombineRex",
            dependencies: ["SwiftRex"],
            path: "Sources/CombineRex"
        ),
        .target(
            name: "RxSwiftRex",
            dependencies: [
                "SwiftRex",
                .product(name: "RxSwift", package: "RxSwift")
            ],
            path: "Sources/RxSwiftRex"
        ),
        .target(
            name: "ReactiveSwiftRex",
            dependencies: [
                "SwiftRex",
                .product(name: "ReactiveSwift", package: "ReactiveSwift")
            ],
            path: "Sources/ReactiveSwiftRex"
        ),

        // MARK: - Tests

        .testTarget(
            name: "SwiftRexTests",
            dependencies: [
                "SwiftRex",
                .product(name: "CoreFP", package: "FP"),
                .product(name: "DataStructure", package: "FP")
            ],
            path: "Tests/SwiftRexTests"
        ),
        .testTarget(
            name: "CombineRexTests",
            dependencies: ["CombineRex"],
            path: "Tests/CombineRexTests"
        ),
        .testTarget(
            name: "RxSwiftRexTests",
            dependencies: ["RxSwiftRex"],
            path: "Tests/RxSwiftRexTests"
        ),
        .testTarget(
            name: "ReactiveSwiftRexTests",
            dependencies: ["ReactiveSwiftRex"],
            path: "Tests/ReactiveSwiftRexTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
