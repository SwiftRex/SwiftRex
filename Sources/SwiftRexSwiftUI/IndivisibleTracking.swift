// SPDX-License-Identifier: Apache-2.0

import Foundation
#if canImport(CoreGraphics)
    import CoreGraphics
#endif

/// A type read **as one unit** — the opt-out from granular tracking.
///
/// Reading through a `ViewStore`'s `state` is granular by default: `viewStore.state.player` is a
/// `GranularTracking` position that keeps extending the key path, so `viewStore.state.player.title` depends on
/// `\.player.title` only. The walk stops at a type conforming to `IndivisibleTracking`: it comes back as itself,
/// and the view invalidates only when that value changes under `==`.
///
/// The primitives ship as leaves (strings, numbers, `Bool`, `Date`, `UUID`, `URL`, `Data`, `Decimal`, the
/// CoreGraphics geometry types) together with optionals and collections of leaves. Opt your own type in
/// when you want it read whole — a small enum or value that is always consumed as a unit:
///
/// ```swift
/// extension Status: IndivisibleTracking {}
/// Text(viewStore.state.status.label)   // `viewStore.state.status` is now a `Status`, not a position
/// ```
///
/// Without the conformance the member is a position — reach the whole value with `.value`.
public protocol IndivisibleTracking: Sendable, Equatable {}

extension String: IndivisibleTracking {}
extension Substring: IndivisibleTracking {}
extension Character: IndivisibleTracking {}
extension Bool: IndivisibleTracking {}

extension Int: IndivisibleTracking {}
extension Int8: IndivisibleTracking {}
extension Int16: IndivisibleTracking {}
extension Int32: IndivisibleTracking {}
extension Int64: IndivisibleTracking {}
extension UInt: IndivisibleTracking {}
extension UInt8: IndivisibleTracking {}
extension UInt16: IndivisibleTracking {}
extension UInt32: IndivisibleTracking {}
extension UInt64: IndivisibleTracking {}
extension Float: IndivisibleTracking {}
extension Double: IndivisibleTracking {}

extension Decimal: IndivisibleTracking {}
extension Date: IndivisibleTracking {}
extension UUID: IndivisibleTracking {}
extension URL: IndivisibleTracking {}
extension Data: IndivisibleTracking {}

#if canImport(CoreGraphics)
    extension CGFloat: IndivisibleTracking {}
    extension CGPoint: IndivisibleTracking {}
    extension CGSize: IndivisibleTracking {}
    extension CGRect: IndivisibleTracking {}
    extension CGVector: IndivisibleTracking {}
#endif

extension Optional: IndivisibleTracking where Wrapped: IndivisibleTracking {}
extension Array: IndivisibleTracking where Element: IndivisibleTracking {}
extension ContiguousArray: IndivisibleTracking where Element: IndivisibleTracking {}
extension Set: IndivisibleTracking where Element: IndivisibleTracking {}
