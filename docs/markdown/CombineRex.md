# CombineRex Docs
The SwiftRex implementation for Swift Combine framework

[CombineRex](https://swiftrex.github.io/SwiftRex/api/CombineRex/index.html)

[![CombineRex](https://swiftrex.github.io/SwiftRex/api/CombineRex/badge.svg)](https://swiftrex.github.io/SwiftRex/api/CombineRex/index.html)

# Installation

## CocoaPods

Create or modify the Podfile at the root folder of your project.

For Combine:
```ruby
# Podfile
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'MyAppTarget' do
  pod 'CombineRex'
end
```

As seen above, some lines are optional because the final Podspecs already include the correct dependencies.

Then, all you must do is install your pods and open the `.xcworkspace` instead of the `.xcodeproj` file:

```shell
$ pod install
$ xed .
```

## Swift Package Manager

Create or modify the Package.swift at the root folder of your project.

```swift
// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "MyApp",
  dependencies: [
    .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.7.0")
  ],
  targets: [
    .target(name: "MyApp", dependencies: ["CombineRex"])
  ]
)
```

Then you can either building on the terminal or use Xcode 11 or higher that now supports SPM natively.

```shell
$ swift build
$ xed .
```

## Carthage

Carthage is currently not our recommended way of using SwiftRex and its support can be dropped future versions. If this is critical for you or your company, please contact us and we will take this into account.

Add this to your Cartfile:

```ruby
github "SwiftRex/SwiftRex" ~> 0.7.0
```

Run

```shell
$ carthage update
```

Then follow the instructions from [Carthage README](https://github.com/Carthage/Carthage#getting-started).