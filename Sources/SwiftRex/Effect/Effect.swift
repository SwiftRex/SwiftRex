import CoreFP

/// A lazy, push-based description of side-effectful work that produces zero or more actions.
///
/// `Effect<Action>` is the currency of async work in SwiftRex. It is a pure value that
/// *describes* work without starting it — the ``Store`` is the sole executor. This design
/// makes effects trivially testable (just inspect the returned value) and composable via
/// the `Monoid` instance.
///
/// ## Push-based, not AsyncStream
///
/// `Effect` uses a closure-based, push-based model rather than Swift's `AsyncStream`. This
/// choice has concrete consequences:
///
/// - **Lazy**: subscribing the closure starts the work; holding the value does nothing.
/// - **Multi-consumer**: the same `Effect` value can be subscribed multiple times, each
///   subscription getting its own independent stream of values.
/// - **Cross-platform**: the model works on Linux, Windows, and WASM where Swift Concurrency
///   may be unavailable or constrained.
/// - **Framework-agnostic**: bridge targets (CombineRex, RxSwiftRex, ReactiveSwiftRex) wrap
///   their respective publisher/observable/signal types into this single representation.
///
/// ## The subscribe closure
///
/// Each component's `subscribe` closure receives two callbacks and returns a
/// ``SubscriptionToken``:
///
/// - `send`: called for each action produced. The ``DispatchedAction`` carries the original
///   call-site provenance so logging middleware sees where each action originated.
/// - `complete`: called exactly once when the component is done producing values.
///   Cancelled components **must not** call `complete`.
///
/// The returned ``SubscriptionToken`` lets the Store cancel the subscription.
///
/// ## Array-of-components internal representation
///
/// Combining two effects (via ``combine(_:_:)`` or the ``Monoid`` instance) appends their
/// component arrays. The Store schedules each component independently under its own
/// ``EffectScheduling`` policy, so cancelling by id never affects components with a
/// different id.
///
/// ## Scheduling
///
/// Apply ``scheduling(_:)`` to override the default ``EffectScheduling/immediately`` policy
/// on all components at once, or build components with individual policies using the
/// ``Effect/init(subscribe:scheduling:)`` SPI. For most production code, use the dedicated
/// factories (``just(_:scheduling:file:function:line:)-5i6kl``, ``sequence(_:scheduling:file:function:line:)``).
///
/// ## Composing effects
///
/// ```swift
/// // Two effects run concurrently — appends their component arrays
/// let combined = Effect.combine(fetchUsers, fetchSettings)
///
/// // Chain via Monoid fold
/// let all: Effect<AppAction> = mconcat([fetchUsers, fetchSettings, trackEvent])
///
/// // Map to change the action type (Functor)
/// let mapped = userEffect.map { AppAction.users($0) }
/// ```
///
/// - Note: Creating an `Effect` starts no work. Only the Store calls `subscribe`.
public struct Effect<Action: Sendable>: Sendable {
    /// A single independently-scheduled unit of work within an ``Effect``.
    ///
    /// An `Effect` is an array of `Component` values. Each component carries its own
    /// ``EffectScheduling`` policy, allowing fine-grained control when combining effects
    /// from different sources.
    package struct Component: Sendable {
        /// The push-based subscription closure.
        ///
        /// - Parameters:
        ///   - send: Called for each action produced. Thread-safe — the Store dispatches
        ///     each call back onto `@MainActor` via a `Task`.
        ///   - complete: Called exactly once when the component is done. Must not be called
        ///     by cancelled components.
        /// - Returns: A ``SubscriptionToken`` the Store holds to cancel the subscription.
        package let subscribe: @Sendable (
            _ send: @escaping @Sendable (DispatchedAction<Action>) -> Void,
            _ complete: @escaping @Sendable () -> Void
        ) -> SubscriptionToken
        /// The scheduling policy the Store applies before starting this component.
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

    /// The ordered list of independently-scheduled components.
    ///
    /// The Store iterates this array after every dispatch, scheduling each component
    /// according to its ``EffectScheduling`` policy. The order of components within the
    /// array affects only the order that `schedule` calls happen, not the order actions
    /// are produced (which is determined by the async work itself).
    package let components: [Component]

    package init(components: [Component]) {
        self.components = components
    }
}

// MARK: - Bridge init (for packages outside this repo)

extension Effect {
    /// Creates a single-component `Effect` from a subscribe closure and an optional scheduling policy.
    ///
    /// This SPI initialiser is intended for bridge targets (CombineRex, RxSwiftRex, etc.) and
    /// extension packages that need to wrap a framework-specific publisher into an `Effect`
    /// without access to the internal `Component` type. Application code should prefer the
    /// typed factories: ``just(_:scheduling:file:function:line:)-5i6kl``,
    /// ``sequence(_:scheduling:file:function:line:)``, or the async/Combine/Rx overloads in
    /// the respective bridge modules.
    ///
    /// - Parameters:
    ///   - subscribe: The push-based subscription closure. Receives `send` and `complete`
    ///     callbacks; must return a ``SubscriptionToken`` that cancels the work.
    ///   - scheduling: The ``EffectScheduling`` policy for this component.
    ///     Defaults to ``EffectScheduling/immediately``.
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
    /// Returns a new `Effect` with `policy` applied to every component.
    ///
    /// Use this when you have an effect built from a factory but want to override its
    /// default ``EffectScheduling/immediately`` policy:
    ///
    /// ```swift
    /// // Debounce a search effect by 300 ms
    /// let searchEffect = apiEffect
    ///     .scheduling(.debounce(id: "search", delay: 0.3))
    ///
    /// // Ensure only one fetch runs at a time
    /// let fetchEffect = fetchData()
    ///     .scheduling(.replacing(id: "fetch"))
    /// ```
    ///
    /// - Parameter policy: The new ``EffectScheduling`` to apply.
    /// - Returns: A copy of this effect with every component's scheduling replaced by `policy`.
    public func scheduling(_ policy: EffectScheduling) -> Self {
        Effect(components: components.map { Component(subscribe: $0.subscribe, scheduling: policy) })
    }
}

// MARK: - Semigroup & Monoid

extension Effect: Semigroup {
    /// Combines two effects so that their components run concurrently.
    ///
    /// Internally this appends `rhs.components` to `lhs.components`. The Store schedules
    /// all components after each dispatch, so both effects run side-by-side with no ordering
    /// guarantee between their produced actions.
    ///
    /// ```swift
    /// // Both effects start concurrently when the Store processes the action
    /// let both = Effect.combine(fetchUsers, logEvent)
    /// ```
    ///
    /// - Parameters:
    ///   - lhs: The first effect.
    ///   - rhs: The second effect.
    /// - Returns: An effect whose components are the concatenation of both inputs.
    public static func combine(_ lhs: Effect, _ rhs: Effect) -> Effect {
        Effect(components: lhs.components + rhs.components)
    }
}

extension Effect: Monoid {
    /// The empty effect — no components, no work, no actions produced.
    ///
    /// Equivalent to ``empty``. Acts as the identity element for ``combine(_:_:)``:
    /// `combine(e, identity) == combine(identity, e) == e` for any effect `e`.
    public static var identity: Effect { Effect(components: []) }
}
