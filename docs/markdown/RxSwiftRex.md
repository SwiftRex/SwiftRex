# RxSwiftRex Docs
The SwiftRex implementation for RxSwift framework

[RxSwiftRex](https://swiftrex.github.io/SwiftRex/api/RxSwiftRex/index.html)

[![RxSwiftRex](https://swiftrex.github.io/SwiftRex/api/RxSwiftRex/badge.svg)](https://swiftrex.github.io/SwiftRex/api/RxSwiftRex/index.html)

# Installation

## CocoaPods

Create or modify the Podfile at the root folder of your project.

For RxSwift:
```ruby
# Podfile
source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

target 'MyAppTarget' do
  pod 'RxSwiftRex'
end
```

As seen above, some lines are optional because the final Podspecs already include the correct dependencies.

Then, all you must do is install your pods and open the `.xcworkspace` instead of the `.xcodeproj` file:

```shell
$ pod install
$ xed .
```

## Swift Package Manager

Currently, only Combine is supported by this method.

## Carthage

Carthage is currently not our recommended way of using SwiftRex and its support can be dropped future versions. If this is critical for you or your company, please contact us and we will take this into account.

Add this to your Cartfile:

```ruby
github "SwiftRex/SwiftRex" ~> 0.6.0
```

Run

```shell
$ carthage update
```

Then follow the instructions from [Carthage README](https://github.com/Carthage/Carthage#getting-started).