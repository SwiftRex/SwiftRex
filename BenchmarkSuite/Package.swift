// swift-tools-version: 6.2
import PackageDescription

// Benchmarks live in a nested package so the published SwiftRex library never gains a
// dependency on package-benchmark (or its jemalloc system requirement). It references the
// root package by path and is built/run only by the dedicated, non-gating CI benchmark job.
let package = Package(
    name: "SwiftRexBenchmarks",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/luizmb/FP.git", from: "1.11.1"),
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.4.0")
    ],
    targets: [
        .executableTarget(
            name: "SwiftRexBenchmarks",
            dependencies: [
                .product(name: "SwiftRex", package: "SwiftRex"),
                .product(name: "CoreFP", package: "FP"),
                .product(name: "Benchmark", package: "package-benchmark")
            ],
            path: "Benchmarks/SwiftRexBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
