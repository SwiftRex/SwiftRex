// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "SwiftRex",
    products: [
        .library(name: "SwiftRex", targets: ["SwiftRex"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .exact("4.5.0"))
    ],
    targets: [
        .target(name: "SwiftRex", dependencies: ["RxSwift"], path: "Sources"),
        .testTarget(name: "UnitTests RxSwift", dependencies: ["SwiftRex", "RxTest", "RxBlocking", "RxSwift"], path: "UnitTests")
    ]
)
