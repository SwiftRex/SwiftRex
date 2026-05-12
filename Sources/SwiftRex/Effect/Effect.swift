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
/// **Completion contract.** Each component signals when it is done producing values by calling
/// the `complete` callback. Cancelled effects MUST NOT call `complete` — this is what makes
/// `Effect.then` cascade correctly. The Store uses completion to clean up its lifecycle state.
///
/// **Array-of-components internal representation.** Combining two effects appends their
/// component arrays. The Store schedules each component independently, so cancelling a
/// component by its id never affects components with a different id.
public struct Effect<Action: Sendable>: Sendable {
    package struct Component: Sendable {
        package let subscribe: @Sendable (
            _ send: @escaping @Sendable (DispatchedAction<Action>) -> Void,
            _ complete: @escaping @Sendable () -> Void
        ) -> SubscriptionToken
        package let scheduling: EffectScheduling

        package init(
            subscribe: @escaping @Sendable (
                _ send: @escaping @Sendable (DispatchedAction<Action>) -> Void,
                _ complete: @escaping @Sendable () -> Void
            ) -> SubscriptionToken,
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
    @_spi(EffectBridging)
    public init(
        subscribe: @escaping @Sendable (
            _ send: @escaping @Sendable (DispatchedAction<Action>) -> Void,
            _ complete: @escaping @Sendable () -> Void
        ) -> SubscriptionToken,
        scheduling: EffectScheduling = .immediately
    ) {
        components = [Component(subscribe: subscribe, scheduling: scheduling)]
    }
}

// MARK: - Scheduling modifier

extension Effect {
    public func scheduling(_ policy: EffectScheduling) -> Self {
        Effect(components: components.map { Component(subscribe: $0.subscribe, scheduling: policy) })
    }
}

// MARK: - Semigroup & Monoid

extension Effect: Semigroup {
    public static func combine(_ lhs: Effect, _ rhs: Effect) -> Effect {
        Effect(components: lhs.components + rhs.components)
    }
}

extension Effect: Monoid {
    public static var identity: Effect { Effect(components: []) }
}
