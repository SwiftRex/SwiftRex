import CoreFP

/// A lazy, opaque description of side-effectful work that produces zero or more actions and a
/// `SubscriptionToken` the Store can use to cancel it.
///
/// `Effect<Action>` is parameterised over the raw action type. Internally every component's
/// subscribe closure receives `(DispatchedAction<Action>) -> Void` — dispatcher provenance is
/// always present. Factories that take a raw `Action` capture the call site automatically;
/// factories that take a `DispatchedAction<Action>` forward the existing source unchanged.
///
/// **Creating an Effect starts no work.** The Store is the sole executor.
///
/// **Array-of-components internal representation.** Combining two effects appends their
/// component arrays. The Store schedules each component independently, so cancelling a
/// component by its id never affects components with a different id.
public struct Effect<Action: Sendable>: Sendable {
    package struct Component: Sendable {
        package let subscribe: @Sendable (@escaping @Sendable (DispatchedAction<Action>) -> Void) -> SubscriptionToken
        package let scheduling: EffectScheduling

        package init(
            subscribe: @escaping @Sendable (@escaping @Sendable (DispatchedAction<Action>) -> Void) -> SubscriptionToken,
            scheduling: EffectScheduling
        ) {
            self.subscribe = subscribe
            self.scheduling = scheduling
        }
    }

    package let components: [Component]

    package init(components: [Component]) {
        self.components = components
    }
}

// MARK: - Bridge init (for packages outside this repo)

extension Effect {
    /// Initialiser for community bridge packages that live outside this `Package.swift`.
    ///
    /// Targets within the monorepo access `Effect` internals via `package` visibility.
    /// External bridge packages import SwiftRex with `@_spi(EffectBridging) import SwiftRex`.
    @_spi(EffectBridging)
    public init(
        subscribe: @escaping @Sendable (@escaping @Sendable (DispatchedAction<Action>) -> Void) -> SubscriptionToken,
        scheduling: EffectScheduling = .immediately
    ) {
        components = [Component(subscribe: subscribe, scheduling: scheduling)]
    }
}

// MARK: - Scheduling modifier

extension Effect {
    /// Returns a copy of this effect with every component's scheduling replaced by `policy`.
    ///
    /// Typically called on a single-component effect before combining:
    /// ```swift
    /// Effect.task { await api.search(query) }
    ///     .scheduling(.debounce(id: "search", delay: 0.3))
    /// ```
    public func scheduling(_ policy: EffectScheduling) -> Self {
        Effect(components: components.map { Component(subscribe: $0.subscribe, scheduling: policy) })
    }
}

// MARK: - Semigroup & Monoid

extension Effect: Semigroup {
    /// Combines two effects by appending their component arrays.
    ///
    /// The Store schedules each component independently — cancelling one component by its id
    /// never affects components with a different id, even within the same combined effect.
    public static func combine(_ lhs: Effect, _ rhs: Effect) -> Effect {
        Effect(components: lhs.components + rhs.components)
    }
}

extension Effect: Monoid {
    /// The empty effect — no work, no actions produced.
    public static var identity: Effect { Effect(components: []) }
}
