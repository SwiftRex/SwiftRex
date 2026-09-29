// SPDX-License-Identifier: Apache-2.0

import Foundation
#if canImport(CoreGraphics)
    import CoreGraphics
#endif

/// A state member that an observable store hands back **as a value** — read whole, compared with `==`.
///
/// Reading through an ``ObservableStoreType`` is granular by default: `store.player` is a ``StateNode``
/// that keeps extending the key path, so `store.player.title` depends on `\.player.title` only. The walk
/// stops at a leaf — a type conforming to `ObservableLeaf` comes back as itself, and the view invalidates
/// only when that value changes under `==`.
///
/// The primitives ship as leaves (strings, numbers, `Bool`, `Date`, `UUID`, `URL`, `Data`, `Decimal`, the
/// CoreGraphics geometry types) together with optionals and collections of leaves. Opt your own type in
/// when you want it read whole — a small enum or value that is always consumed as a unit:
///
/// ```swift
/// extension Status: ObservableLeaf {}
/// Text(store.status.label)   // `store.status` is now a `Status`, not a node
/// ```
///
/// Without the conformance the member is a node — reach the value with ``StateNode/value``.
public protocol ObservableLeaf: Sendable, Equatable {}

extension String: ObservableLeaf {}
extension Substring: ObservableLeaf {}
extension Character: ObservableLeaf {}
extension Bool: ObservableLeaf {}

extension Int: ObservableLeaf {}
extension Int8: ObservableLeaf {}
extension Int16: ObservableLeaf {}
extension Int32: ObservableLeaf {}
extension Int64: ObservableLeaf {}
extension UInt: ObservableLeaf {}
extension UInt8: ObservableLeaf {}
extension UInt16: ObservableLeaf {}
extension UInt32: ObservableLeaf {}
extension UInt64: ObservableLeaf {}
extension Float: ObservableLeaf {}
extension Double: ObservableLeaf {}

extension Decimal: ObservableLeaf {}
extension Date: ObservableLeaf {}
extension UUID: ObservableLeaf {}
extension URL: ObservableLeaf {}
extension Data: ObservableLeaf {}

#if canImport(CoreGraphics)
    extension CGFloat: ObservableLeaf {}
    extension CGPoint: ObservableLeaf {}
    extension CGSize: ObservableLeaf {}
    extension CGRect: ObservableLeaf {}
    extension CGVector: ObservableLeaf {}
#endif

extension Optional: ObservableLeaf where Wrapped: ObservableLeaf {}
extension Array: ObservableLeaf where Element: ObservableLeaf {}
extension ContiguousArray: ObservableLeaf where Element: ObservableLeaf {}
extension Set: ObservableLeaf where Element: ObservableLeaf {}
