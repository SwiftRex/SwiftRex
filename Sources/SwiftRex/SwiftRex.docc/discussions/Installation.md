# Installation

Instructions about setting it up using CocoaPods or Swift Package Manager.

## Overview

### CocoaPods

Create or modify the Podfile at the root folder of your project. Your settings will depend on the ReactiveFramework of your choice.

For Combine:
```ruby
# Podfile
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'MyAppTarget' do
  pod 'CombineRex'
end
```

For RxSwift:
```ruby
# Podfile
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'MyAppTarget' do
  pod 'RxSwiftRex'
end
```

For ReactiveSwift:
```ruby
# Podfile
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'MyAppTarget' do
  pod 'ReactiveSwiftRex'
end
```

As seen above, some lines are optional because the final Podspecs already include the correct dependencies.

Then, all you must do is install your pods and open the `.xcworkspace` instead of the `.xcodeproj` file:

```shell
$ pod install
$ xed .
```

### Swift Package Manager

Create or modify the Package.swift at the root folder of your project.
You can use the automatic linking mode (static/dynamic), or use the project with suffix Dynamic to force
dynamic linking and overcome current Xcode limitations to resolve diamond dependency issues.

If you use it from only one target, automatic mode should be fine.

Combine, automatic linking mode:
```swift
// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "MyApp",
  platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
  products: [
    .executable(name: "MyApp", targets: ["MyApp"])
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.12")
  ],
  targets: [
    .target(name: "MyApp", dependencies: [.product(name: "CombineRex", package: "SwiftRex")])
  ]
)
```

RxSwift, automatic linking mode:
```swift
// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "MyApp",
  platforms: [.macOS(.v10_10), .iOS(.v8), .tvOS(.v9), .watchOS(.v3)],
  products: [
    .executable(name: "MyApp", targets: ["MyApp"])
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.12")
  ],
  targets: [
    .target(name: "MyApp", dependencies: [.product(name: "RxSwiftRex", package: "SwiftRex")])
  ]
)
```

ReactiveSwift, automatic linking mode:
```swift
// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "MyApp",
  platforms: [.macOS(.v10_10), .iOS(.v8), .tvOS(.v9), .watchOS(.v3)],
  products: [
    .executable(name: "MyApp", targets: ["MyApp"])
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.12")
  ],
  targets: [
    .target(name: "MyApp", dependencies: [.product(name: "ReactiveSwiftRex", package: "SwiftRex")])
  ]
)
```

Combine, dynamic linking mode (use similar approach of appending "Dynamic" also for RxSwift or ReactiveSwift products):
```swift
// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "MyApp",
  platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
  products: [
    .executable(name: "MyApp", targets: ["MyApp"])
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.12")
  ],
  targets: [
    .target(name: "MyApp", dependencies: [.product(name: "CombineRexDynamic", package: "SwiftRex")])
  ]
)
```

Then you can either building on the terminal or use Xcode 11 or higher that now supports SPM natively.

```shell
$ swift build
$ xed .
```

> **_IMPORTANT:_** For Xcode 12, please use the version 0.8.8. Versions 0.9.0 and above require Xcode 13.

### Carthage

Carthage is no longer supported due to lack of interest and high maintenance effort.

In case this is REALLY critical for you, please open a Github issue and let us know, we will evaluate
the possibility to bring it back. In meantime you can check last  Carthage compatible version, which
was 0.7.1, and eventually target that version until we come up with a better solution.
