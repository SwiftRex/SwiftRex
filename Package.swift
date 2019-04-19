// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "SwiftRex",
    products: [
        .library(name: "SwiftRex RxSwift", targets: ["SwiftRex RxSwift"]),
        .library(name: "SwiftRex ReactiveSwift", targets: ["SwiftRex ReactiveSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .exact("4.5.0")),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", .exact("6.0.0"))
    ],
    targets: [
        .target(name: "SwiftRex RxSwift", dependencies: ["RxSwift"]),
        .target(name: "SwiftRex ReactiveSwift", dependencies: ["ReactiveSwift"]),
        .testTarget(name: "UnitTests RxSwift", dependencies: ["SwiftRex RxSwift", "RxTest", "RxBlocking", "RxSwift"], path: "UnitTests")
    ],
    swiftLanguageVersions: [.v5]
)
