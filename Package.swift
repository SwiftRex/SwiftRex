// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "SwiftRex",
    products: [
        .library(name: "SwiftRex", targets: ["SwiftRex"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .exact("5.0.0"))
    ],
    targets: [
        .target(name: "SwiftRex", dependencies: ["RxSwift"], path: "Sources")
    ],
    swiftLanguageVersions: [.v5]
)
