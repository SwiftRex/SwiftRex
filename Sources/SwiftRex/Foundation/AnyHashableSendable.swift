// SPDX-License-Identifier: Apache-2.0

/// A type-erased effect identifier that is both `Hashable` and `Sendable`, with
/// platform-uniform, type-identity-aware equality.
///
/// `AnyHashableSendable` is the key type of the ``Store``'s effect registry and the payload of
/// every ``EffectScheduling`` case that carries an `id`. It exists instead of `AnyHashable`
/// for two reasons:
///
/// 1. **Sendability.** `AnyHashable` does not conform to `Sendable` on all supported
///    toolchains, and declaring a retroactive conformance from a library leaks that
///    conformance into every client binary. Storing `any Hashable & Sendable` makes the
///    guarantee compiler-checked with no `@unchecked` anywhere.
/// 2. **Equality semantics.** On Apple platforms `AnyHashable` bridges numeric types,
///    `Bool`, and strings through their Objective-C counterparts, so `AnyHashable(1)`,
///    `AnyHashable(1.0)`, and `AnyHashable(true)` all compare equal — while on Linux they
///    do not. Two features using the ids `1` (Int) and `true` (Bool) would cancel each
///    other's effects on iOS but not on Linux. `AnyHashableSendable` requires the **exact
///    same dynamic type** plus value equality, so comparisons behave identically on every
///    platform and never unify distinct id types.
///
/// ## Choosing effect ids
///
/// Because equality is type-aware, the safest ids are module-private enums — two enums with
/// the same case names in different features are different types and can never collide:
///
/// ```swift
/// enum EffectID { case fetch, search }
///
/// return .produce { ctx in
///     ctx.environment.api.search(query).asEffect()
///         .scheduling(.debounce(id: EffectID.search, delay: .milliseconds(300)))
/// }
/// ```
///
/// String and integer literals also work, but share a single namespace per type across the
/// whole store — prefer enums when multiple features schedule effects.
public struct AnyHashableSendable: Hashable, Sendable {
    /// The wrapped identifier value.
    public let base: any Hashable & Sendable

    /// Wraps any `Hashable & Sendable` value.
    ///
    /// - Parameter base: The identifier value to wrap.
    public init(_ base: some Hashable & Sendable) {
        self.base = base
    }

    /// Type-identity-aware equality: `true` only when both wrapped values have the exact
    /// same dynamic type **and** compare equal as that type. Never bridges across types.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        isEqual(lhs.base, rhs.base)
    }

    /// Hashes the dynamic type identity together with the wrapped value's own hash,
    /// keeping the `Hashable` contract consistent with the type-aware equality.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type(of: base)))
        base.hash(into: &hasher)
    }
}

// The explicit dynamic-type check must happen before the cast: a bare `as?` between
// numeric types bridges through NSNumber on Apple platforms (`(1 as Any) as? Double`
// succeeds there, fails on Linux), which would make equality asymmetric and
// platform-dependent.
private func isEqual<L: Hashable & Sendable>(_ lhs: L, _ rhs: any Hashable & Sendable) -> Bool {
    guard type(of: rhs) == L.self, let rhs = rhs as? L else { return false }
    return lhs == rhs
}
