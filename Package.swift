// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "SwiftRex",
    products: [
        .library(name: "SwiftRex", targets: ["SwiftRex"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "4.2.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "7.1.1"))
    ],
    targets: [
        .target(name: "SwiftRex", dependencies: ["RxSwift"], path: "Sources"),
        .testTarget(name: "UnitTests", dependencies: ["SwiftRex", "Nimble", "RxTest", "RxBlocking", "RxSwift"], path: "UnitTests")
    ]
)
