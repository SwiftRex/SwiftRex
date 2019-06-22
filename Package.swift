// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "SwiftRex",
    products: [
        .library(name: "SwiftRex", targets: ["SwiftRex"]),
        .library(name: "SwiftRexForRac", targets: ["SwiftRexForRac"]),
        .library(name: "SwiftRexForRx", targets: ["SwiftRexForRx"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", .exact("6.0.0")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .exact("5.0.0"))
    ],
    targets: [
        .target(name: "SwiftRex", dependencies: [], path: "Sources/Common"),
        .target(name: "SwiftRexForRac", dependencies: ["SwiftRex", "ReactiveSwift"], path: "Sources/ReactiveSwift"),
        .target(name: "SwiftRexForRx", dependencies: ["SwiftRex", "RxSwift"], path: "Sources/RxSwift")
    ],
    swiftLanguageVersions: [.v5]
)
