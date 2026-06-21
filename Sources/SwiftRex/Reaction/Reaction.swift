import CoreFP
import DataStructure

/// The return of a ``Middleware``/``Behavior``'s **action** side (`react`): a deferred
/// `(PostReducerContext) -> Effect` the Store runs in phase 3, after the mutation.
///
/// A `Reaction` is what you produce when you *react to an action* — it reads `ctx.environment` and
/// `ctx.liveState` and returns the ``Effect`` to schedule (which may `.open`/`.broadcast`/`.cancel`
/// a ``Channel``). It is just a `Reader`, so it composes and lifts like any reader-valued effect.
///
/// ```swift
/// .react { action, _ in
///     Reaction { ctx in ctx.environment.api.search(query).asEffect(.results) }
/// }
/// ```
public typealias Reaction<Action: Sendable, State: Sendable, Environment: Sendable> =
    Reader<PostReducerContext<State, Environment>, Effect<Action>>

/// The return of a ``Middleware``/``Behavior``'s **state** side (`supervise`): a deferred
/// `(Environment) -> [Channel]` giving the *complete* set of channels that should be alive for the
/// state `supervise` was called with.
///
/// State is the input to `supervise`; the environment arrives through this `Reader`, so the channels
/// get their dependencies. The engine reconciles successive sets — opening, recreating, piping, and
/// cancelling — so you keep no bookkeeping.
///
/// ```swift
/// .supervise { state in
///     Keep { env in state.connected ? [Channel(id: "socket") { dispatch in … }] : [] }
/// }
/// ```
public typealias Keep<Action: Sendable, Environment: Sendable> =
    Reader<Environment, [Channel<Action>]>

// MARK: - Engine bridge

extension Channel {
    /// The engine reconcile entry for this channel — a single keyed component plus its two diff
    /// identities (`resetIdentity` for recreate, `broadcastIdentity` for pipe).
    package var reconcileEntry: EffectEngine<Action>.ReconcileEntry {
        .init(component: component, resetIdentity: resetIdentity, broadcastIdentity: broadcastIdentity)
    }
}
