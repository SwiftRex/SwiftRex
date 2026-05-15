// swift-tools-version: 6.2
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
        .library(name: "SwiftRex.Operators", targets: ["SwiftRexOperators"]),
        .library(name: "SwiftRex.Concurrency", targets: ["SwiftRexConcurrency"]),
        .library(name: "SwiftRex.Combine", targets: ["SwiftRexCombine"]),
        .library(name: "SwiftRex.RxSwift", targets: ["SwiftRexRxSwift"]),
        .library(name: "SwiftRex.ReactiveSwift", targets: ["SwiftRexReactiveSwift"]),
        .library(name: "SwiftRex.SwiftUI", targets: ["SwiftRexSwiftUI"]),
        .library(name: "SwiftRex.Testing", targets: ["SwiftRexTesting"])
    ],
    dependencies: [
        .package(url: "https://github.com/luizmb/FP.git", from: "1.6.6"),
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

        // MARK: - Concurrency bridge

        .target(
            name: "SwiftRexConcurrency",
            dependencies: [
                "SwiftRex",
                .product(name: "CoreFP", package: "FP")
            ],
            path: "Sources/SwiftRexConcurrency"
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

        // MARK: - Reactive bridges

        .target(
            name: "SwiftRexCombine",
            dependencies: ["SwiftRex"],
            path: "Sources/SwiftRexCombine"
        ),
        .target(
            name: "SwiftRexRxSwift",
            dependencies: [
                "SwiftRex",
                .product(name: "RxSwift", package: "RxSwift")
            ],
            path: "Sources/SwiftRexRxSwift"
        ),
        .target(
            name: "SwiftRexReactiveSwift",
            dependencies: [
                "SwiftRex",
                .product(name: "ReactiveSwift", package: "ReactiveSwift")
            ],
            path: "Sources/SwiftRexReactiveSwift"
        ),

        // MARK: - SwiftUI wrappers

        .target(
            name: "SwiftRexSwiftUI",
            dependencies: ["SwiftRex"],
            path: "Sources/SwiftRexSwiftUI"
        ),

        // MARK: - Testing utilities

        .target(
            name: "SwiftRexTesting",
            dependencies: [
                "SwiftRex",
                .product(name: "CoreFP", package: "FP")
            ],
            path: "Sources/SwiftRexTesting"
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
            name: "SwiftRexConcurrencyTests",
            dependencies: ["SwiftRexConcurrency", "SwiftRex"],
            path: "Tests/SwiftRexConcurrencyTests"
        ),
        .testTarget(
            name: "SwiftRexCombineTests",
            dependencies: ["SwiftRexCombine"],
            path: "Tests/SwiftRexCombineTests"
        ),
        .testTarget(
            name: "SwiftRexRxSwiftTests",
            dependencies: ["SwiftRexRxSwift"],
            path: "Tests/SwiftRexRxSwiftTests"
        ),
        .testTarget(
            name: "SwiftRexReactiveSwiftTests",
            dependencies: ["SwiftRexReactiveSwift"],
            path: "Tests/SwiftRexReactiveSwiftTests"
        ),
        .testTarget(
            name: "SwiftRexTestingTests",
            dependencies: [
                "SwiftRexTesting",
                "SwiftRex",
                .product(name: "CoreFP", package: "FP")
            ],
            path: "Tests/SwiftRexTestingTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
