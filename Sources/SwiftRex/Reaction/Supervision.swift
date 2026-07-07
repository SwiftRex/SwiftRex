// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

/// The set of long-lived ``Channel``s that should be alive for a given state — the payload a
/// ``Supervision`` resolves to. *Keep* is what the ``Store`` does to a `supervise` description:
/// it opens, reconciles, and tears these channels down so the live set always matches the state.
///
/// `Keep` is a plain array, so it is a `Monoid` (`[]` is identity, `+` concatenates): unioning two
/// supervisors' channel sets is just appending their `Keep`s.
public typealias Keep<Action: Sendable> = [Channel<Action>]

/// The return of a ``Middleware``/``Behavior``'s **state** side (`supervise`): a deferred
/// `(Environment) -> Keep` giving the *complete* set of channels that should be alive for the state
/// `supervise` was called with.
///
/// State is the input to `supervise`; the environment arrives through this `Reader`, so the channels
/// get their dependencies. The engine reconciles successive sets — opening, recreating, piping, and
/// cancelling — so you keep no bookkeeping. Because `Reader` is a `Monoid` when its `Output` is
/// (`Keep` is), `Supervision` composes for free: combining two is the reader whose output is the
/// concatenation of both channel sets.
///
/// ```swift
/// .supervise { state in
///     Supervision { env in state.connected ? [Channel(id: "socket") { dispatch in … }] : [] }
/// }
/// ```
public typealias Supervision<Action: Sendable, Environment: Sendable> =
    Reader<Environment, Keep<Action>>

/// The return of a ``Middleware``/``Behavior``'s **action** side (`produce`): a deferred
/// `(PostReducerContext) -> Effect` giving the ``Effect`` to perform once the post-mutation
/// context — the committed `State` plus the `Environment` — is available.
///
/// The action is the input to `produce`; the context arrives through this `Reader`, mirroring how
/// ``Supervision`` receives its environment. Because `Reader` is a `Monoid` when its `Output` is
/// (``Effect`` is), `Producer` composes for free.
///
/// ```swift
/// .produce { action, _ in
///     Producer { ctx in ctx.environment.fetch().asEffect(Action.fetched) }
/// }
/// ```
public typealias Producer<Action: Sendable, State: Sendable, Environment: Sendable> =
    Reader<PostReducerContext<State, Environment>, Effect<Action>>

// MARK: - Engine bridge

extension Channel {
    /// The engine reconcile entry for this channel — a single keyed component plus its two diff
    /// identities (`resetIdentity` for recreate, `broadcastIdentity` for pipe).
    package var reconcileEntry: EffectEngine<Action>.ReconcileEntry {
        .init(component: component, resetIdentity: resetIdentity, broadcastIdentity: broadcastIdentity, settle: settle)
    }
}
