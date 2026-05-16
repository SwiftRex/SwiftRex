// swift-tools-version: 6.2
import CompilerPluginSupport
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
        .library(name: "SwiftRex.Architecture", targets: ["SwiftRexArchitecture"]),
        .library(name: "SwiftRex.Testing", targets: ["SwiftRexTesting"])
    ],
    dependencies: [
        .package(url: "https://github.com/luizmb/FP.git", from: "1.6.6"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.10.0"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "7.2.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0")
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

        // MARK: - Macros (implementation — build-time only)

        .macro(
            name: "SwiftRexMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "Sources/SwiftRexMacros"
        ),

        // MARK: - SwiftUI wrappers

        .target(
            name: "SwiftRexSwiftUI",
            dependencies: [
                "SwiftRex",
                "SwiftRexMacros"
            ],
            path: "Sources/SwiftRexSwiftUI"
        ),

        // MARK: - Architecture (opinionated Feature module protocol)

        .target(
            name: "SwiftRexArchitecture",
            dependencies: [
                "SwiftRex",
                "SwiftRexSwiftUI",
                "SwiftRexMacros",
                .product(name: "FPMacros", package: "FP")
            ],
            path: "Sources/SwiftRexArchitecture"
        ),

        // MARK: - Testing helpers
        // TestStore + TestFeature: opt-in product that brings in `Testing`. Kept
        // out of every other target so apps linking SwiftRex don't drag
        // `Testing.framework` into their dyld closure at runtime.

        .target(
            name: "SwiftRexTesting",
            dependencies: [
                "SwiftRex",
                "SwiftRexSwiftUI",
                "SwiftRexArchitecture"
            ],
            path: "Sources/SwiftRexTesting"
        ),

        // MARK: - Tests

        .testTarget(
            name: "SwiftRexTests",
            dependencies: [
                "SwiftRex",
                "SwiftRexTesting",
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
            name: "SwiftRexArchitectureTests",
            dependencies: ["SwiftRexArchitecture", "SwiftRex", "SwiftRexTesting"],
            path: "Tests/SwiftRexArchitectureTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
