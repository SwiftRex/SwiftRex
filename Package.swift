// swift-tools-version:5.1
import PackageDescription

let combineProduct: [Product] = {
    #if !os(Linux) && canImport(Combine)
        return [.library(name: "CombineRex", targets: ["SwiftRex", "CombineRex"])]
    #else
        return []
    #endif
}()

let combineTargets: [Target] = {
    #if !os(Linux) && canImport(Combine)
        return [
            .target(name: "CombineRex", dependencies: ["SwiftRex"]),
            .testTarget(name: "CombineRexTests",
                        dependencies: ["SwiftRex", "CombineRex"])
        ]
    #else
        return []
    #endif
}()

let package = Package(
    name: "SwiftRex",
    platforms: [
        .macOS(SupportedPlatform.MacOSVersion.v10_15),
        .iOS(SupportedPlatform.IOSVersion.v13),
        .tvOS(SupportedPlatform.TVOSVersion.v13),
        .watchOS(SupportedPlatform.WatchOSVersion.v6)
    ],
    products: combineProduct + [
        .library(name: "RxSwiftRex", targets: ["SwiftRex", "RxSwiftRex"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "5.0.0")
    ],
    targets: combineTargets + [
        .target(name: "SwiftRex", dependencies: []),
        .target(name: "RxSwiftRex", dependencies: ["SwiftRex", "RxSwift"])
    ],
    swiftLanguageVersions: [.v5]
)
