# Installation

Add SwiftRex via Swift Package Manager, and enable the package trait for the reactive bridge you want.

## Overview

SwiftRex ships as several products (each its own import). The three third-party reactive bridges —
`SwiftRex.RxSwift`, `SwiftRex.ReactiveSwift`, and `SwiftRex.ReactiveConcurrency` — are each gated
behind a Swift Package Manager **trait** of the same name, and **all traits are off by default**. So a
consumer who picks one bridge never downloads — nor sees in their acknowledgements — the other two.
`SwiftRex`, `SwiftRex.Combine`, and `SwiftRex.SwiftConcurrency` need no trait. Requires a Swift 6.3+
toolchain.

## Swift Package Manager

Add SwiftRex to your `Package.swift`, enabling the trait(s) for the bridge(s) you use:

```swift
dependencies: [
    .package(
        url: "https://github.com/SwiftRex/SwiftRex.git",
        from: "0.8.8",
        // e.g. ["RxSwift", "ReactiveConcurrency"]; omit entirely for core / Combine / SwiftConcurrency only
        traits: ["ReactiveConcurrency"]
    )
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "SwiftRex", package: "SwiftRex"),                      // core — no trait
        .product(name: "SwiftRex.ReactiveConcurrency", package: "SwiftRex"),  // needs the trait enabled above
    ])
]
```

Omit `traits:` entirely if you only use the core, `Combine`, or `SwiftConcurrency` products — then
RxSwift/ReactiveSwift/ReactiveConcurrency are never even resolved.

## Xcode

**File ▸ Add Package Dependencies…**, enter `https://github.com/SwiftRex/SwiftRex.git`, choose a
version or branch, and add the product(s) you need.

To enable a bridge's trait, open **Project ▸ Package Dependencies**: the SwiftRex row has a **Traits**
column — click it and tick the trait(s) you want, keeping `default` checked so SwiftRex's default
traits aren't dropped.

![Enabling the ReactiveConcurrency trait for SwiftRex in Xcode's Package Dependencies](xcode-package-traits)

> Tip: `xcodebuild` ignores a trait declared by a *consumed* package, so an `.xcodeproj` that pulls
> SwiftRex transitively must enable the trait at the **project** level — ticking it writes a
> `traits = ( ReactiveConcurrency, default, );` block onto the SwiftRex package reference in
> `project.pbxproj`. Keep `traits:` in `Package.swift` too (that's what the `swift` CLI uses).
> XcodeGen does not emit package traits, so re-apply the block after each `xcodegen generate`.

## Topics

### Next
- <doc:BuildYourFirstFeature>
