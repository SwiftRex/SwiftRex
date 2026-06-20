import CoreFP

/// A **state-driven** source of effects: a pure, total function `(State) -> [DesiredEffect]` returning
/// the *complete* set of effects that should be alive for the given state.
///
/// `Reaction` is the state-driven counterpart to action-driven effects (`produce`): where `produce`
/// reacts to an **action** and runs a one-shot effect owned by it (Elm's `Cmd`), `react` derives the
/// effects that should *exist* for the current **state** (Elm's `Sub`) and lets the engine reconcile.
///
/// ## You declare what should be; the engine derives the delta
///
/// `react` is recomputed on every state change and returns the **entire** desired set — never a
/// delta. The engine diffs this cycle's set against last cycle's by the desired effect's `id`: it starts
/// effects newly present, cancels effects now absent, and re-schedules effects whose version changed.
/// You keep **no** bookkeeping — like SwiftUI `body` or Elm subscriptions, you re-derive and the
/// framework diffs. An unchanged desired set costs nothing.
///
/// This is what makes state-driven effects survive Redux DevTools time-travel: jump to any past
/// state and `react` recomputes the effects that belong there. It also means you never write
/// cancellation — leaving the screen removes the state that implied the effect, so the reconciler
/// cancels it for you.
///
/// ```swift
/// let appReaction = Reaction<AppState, AppAction> { state in
///     var desired: [DesiredEffect<AppAction>] = []
///     if state.isConnected {
///         desired.append(.channel(id: "socket", value: state.outbox) { send, _ in … })
///     }
///     if state.session.isLoading {
///         desired.append(.effect(id: "refresh", version: state.session.token, refreshEffect))
///     }
///     return desired
/// }
/// ```
///
/// ## Composition
///
/// `Reaction` is a `Monoid`: ``combine(_:_:)`` unions two reactions' desired sets and ``identity``
/// contributes the empty set — so reactions compose and lift exactly like ``Reducer`` and
/// ``Behavior``. Crucially, ``identity`` adds **nothing** to the union; it never means "cancel
/// everything" — cancellation only fires for ids absent from the *total* composed set.
public struct Reaction<State: Sendable, Action: Sendable>: Sendable {
    /// The pure, total function from state to the complete desired-effect set. Must be synchronous —
    /// it runs on every state change.
    public let react: @Sendable (State) -> [DesiredEffect<Action>]

    /// Creates a reaction from a `(State) -> [DesiredEffect]` function.
    public init(_ react: @escaping @Sendable (State) -> [DesiredEffect<Action>]) {
        self.react = react
    }
}

// MARK: - Semigroup & Monoid

extension Reaction: Semigroup {
    /// Unions two reactions: the combined desired set is the concatenation of both, recomputed each
    /// cycle. The reconcile diff runs once on the whole union, so an `identity` summand adds nothing.
    public static func combine(_ lhs: Reaction, _ rhs: Reaction) -> Reaction {
        Reaction { lhs.react($0) + rhs.react($0) }
    }
}

extension Reaction: Monoid {
    /// The empty reaction — desires nothing for any state. Identity for ``combine(_:_:)``; contributes
    /// ∅ to the union (never "cancel everything").
    public static var identity: Reaction { Reaction { _ in [] } }
}

// MARK: - Engine bridge

extension Reaction {
    /// Maps this reaction's desired set for `state` into the engine's reconcile entries, stamping each
    /// effect component with its `(owner, id)` key. Multi-component effects sub-key by index so each
    /// component reconciles independently.
    package func reconcileEntries(_ state: State) -> [EffectEngine<Action>.ReconcileEntry] {
        react(state).flatMap { desired -> [EffectEngine<Action>.ReconcileEntry] in
            let components = desired.effect.components
            return components.enumerated().map { index, component in
                var scheduling = component.scheduling
                scheduling.id = components.count == 1
                    ? desired.id
                    : AnyHashableSendable(IndexedReactionKey(base: desired.id, index: index))
                let stamped = Effect<Action>.Component(
                    subscribe: component.subscribe,
                    channel: component.channel,
                    scheduling: scheduling
                )
                return .init(component: stamped, valueIdentity: desired.version)
            }
        }
    }
}

/// Sub-key for a multi-component desired effect, so each component reconciles under its own key.
private struct IndexedReactionKey: Hashable, Sendable {
    let base: AnyHashableSendable
    let index: Int
}
