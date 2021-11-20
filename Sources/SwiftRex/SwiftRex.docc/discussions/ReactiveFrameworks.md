# Reactive Frameworks

SwiftRex currently supports the 3 major reactive frameworks: Apple Combine, RxSwift and ReactiveSwift.

## Overview

SwiftRex currently supports the 3 major reactive frameworks:
- [Apple Combine](https://developer.apple.com/documentation/combine)
- [RxSwift](https://github.com/ReactiveX/RxSwift)
- [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)

More can be easily added later by implementing some abstraction bridges that can be found in the `ReactiveWrappers.swift` file. To avoid adding unnecessary files to your app, SwiftRex is split in 4 packages:
- SwiftRex: the core library
- CombineRex: the implementation for Combine framework
- RxSwiftRex: the implementation for RxSwift framework
- ReactiveSwiftRex: the implementation for ReactiveSwift framework

SwiftRex itself won't be enough, so you have to pick one of the three implementations.
