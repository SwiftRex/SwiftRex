// swift-tools-version: 6.3
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SwiftRex",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "SwiftRex", targets: ["SwiftRex"]),
        .library(name: "SwiftRex.Operators", targets: ["SwiftRexOperators"]),
        .library(name: "SwiftRex.SwiftConcurrency", targets: ["SwiftRexSwiftConcurrency"]),
        .library(name: "SwiftRex.Combine", targets: ["SwiftRexCombine"]),
        .library(name: "SwiftRex.RxSwift", targets: ["SwiftRexRxSwift"]),
        .library(name: "SwiftRex.ReactiveSwift", targets: ["SwiftRexReactiveSwift"]),
        .library(name: "SwiftRex.ReactiveConcurrency", targets: ["SwiftRexReactiveConcurrency"]),
        .library(name: "SwiftRex.SwiftUI", targets: ["SwiftRexSwiftUI"]),
        .library(name: "SwiftRex.Architecture", targets: ["SwiftRexArchitecture"]),
        .library(name: "SwiftRex.Testing", targets: ["SwiftRexTesting"])
    ],
    // Each third-party reactive bridge is behind an opt-in trait. A consumer who only
    // wants one (e.g. RxSwift) enables that trait and SwiftPM resolves/clones ONLY that
    // package — the others are never fetched and never appear in their acknowledgements.
    // Default is none: pick your champion explicitly. Combine (system) and
    // SwiftConcurrency (no external dependency) need no trait. CI runs with
    // `--enable-all-traits` so every bridge is built and tested.
    traits: [
        .trait(name: "RxSwift"),
        .trait(name: "ReactiveSwift"),
        .trait(name: "ReactiveConcurrency"),
        .default(enabledTraits: [])
    ],
    dependencies: [
        .package(url: "https://github.com/luizmb/FP.git", from: "2.1.0"),
        .package(url: "https://github.com/luizmb/Hourglass.git", from: "1.0.1"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.10.0"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "7.2.0"),
        .package(url: "https://github.com/luizmb/ReactiveConcurrency.git", from: "1.0.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.1"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0")
    ],
    targets: [
        // MARK: - Core

        .target(
            name: "SwiftRex",
            dependencies: [
                .product(name: "CoreFP", package: "FP"),
                .product(name: "DataStructure", package: "FP"),
                .product(name: "Hourglass", package: "Hourglass")
            ],
            path: "Sources/SwiftRex"
        ),

        // MARK: - Concurrency bridge

        .target(
            name: "SwiftRexSwiftConcurrency",
            dependencies: [
                "SwiftRex"
            ],
            path: "Sources/SwiftRexSwiftConcurrency"
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
                .product(name: "RxSwift", package: "RxSwift", condition: .when(traits: ["RxSwift"]))
            ],
            path: "Sources/SwiftRexRxSwift"
        ),
        .target(
            name: "SwiftRexReactiveSwift",
            dependencies: [
                "SwiftRex",
                .product(name: "ReactiveSwift", package: "ReactiveSwift", condition: .when(traits: ["ReactiveSwift"]))
            ],
            path: "Sources/SwiftRexReactiveSwift"
        ),
        .target(
            name: "SwiftRexReactiveConcurrency",
            dependencies: [
                "SwiftRex",
                .product(
                    name: "ReactiveConcurrency",
                    package: "ReactiveConcurrency",
                    condition: .when(traits: ["ReactiveConcurrency"])
                )
            ],
            path: "Sources/SwiftRexReactiveConcurrency"
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

        // MARK: - Codegen tool (dev-only; emits committed lift/on source)

        .executableTarget(
            name: "GenerateLifts",
            path: "Sources/GenerateLifts"
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
                .product(name: "DataStructure", package: "FP"),
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
                "SwiftRexArchitecture",
                .product(name: "DataStructure", package: "FP")
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
                .product(name: "DataStructure", package: "FP"),
                .product(name: "Hourglass", package: "Hourglass")
            ],
            path: "Tests/SwiftRexTests"
        ),
        .testTarget(
            name: "SwiftRexSwiftConcurrencyTests",
            dependencies: ["SwiftRexSwiftConcurrency", "SwiftRex"],
            path: "Tests/SwiftRexSwiftConcurrencyTests"
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
            name: "SwiftRexReactiveConcurrencyTests",
            dependencies: ["SwiftRexReactiveConcurrency"],
            path: "Tests/SwiftRexReactiveConcurrencyTests"
        ),
        .testTarget(
            name: "SwiftRexArchitectureTests",
            dependencies: [
                "SwiftRexArchitecture",
                "SwiftRex",
                "SwiftRexSwiftConcurrency",
                "SwiftRexTesting",
                .product(name: "DataStructure", package: "FP")
            ],
            path: "Tests/SwiftRexArchitectureTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
