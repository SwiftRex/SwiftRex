// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "SwiftRex",
    products: [
        .library(name: "CombineRex", targets: ["SwiftRex", "CombineRex"]),
        .library(name: "ReactiveSwiftRex", targets: ["SwiftRex", "ReactiveSwiftRex"]),
        .library(name: "RxSwiftRex", targets: ["SwiftRex", "RxSwiftRex"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", .exact("6.0.0")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .exact("5.0.0"))
    ],
    targets: [
        .target(name: "SwiftRex", dependencies: [], path: "Sources/Common"),
        .target(name: "CombineRex", dependencies: ["SwiftRex"], path: "Sources/Combine"),
        .target(name: "ReactiveSwiftRex", dependencies: ["SwiftRex", "ReactiveSwift"], path: "Sources/ReactiveSwift"),
        .target(name: "RxSwiftRex", dependencies: ["SwiftRex", "RxSwift"], path: "Sources/RxSwift")
    ],
    swiftLanguageVersions: [.v5]
)
