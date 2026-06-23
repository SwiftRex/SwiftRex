import SwiftRex

// MARK: - AsyncSequence → Channel (state-driven, long-lived subscriptions)
//
// Where `Effect.asyncSequence` turns a sequence into a one-shot effect, `asChannel` turns it into a
// long-lived ``Channel`` — the unit a `supervise` keeps alive. Declare it from state and the Store
// iterates the sequence in a `Task` while the channel is desired, dispatching each element as an
// action, and cancels that `Task` when the channel leaves the desired set.
//
//     .supervise { state in
//         Keep { env in
//             guard state.isListening else { return [] }
//             return [env.events.asChannel(id: "events", AppAction.received)]
//         }
//     }
//
// ## Timing — strictly post-setup, cooperatively cancelled
//
// Unlike a Combine subject, an `AsyncSequence` cannot emit *synchronously during subscription*: the
// iteration runs inside a `Task` that is scheduled only after the channel body returns, so the channel
// is always fully registered before the first element is produced. Each dispatched action additionally
// hops through the Store's `send` (`Task { @MainActor }`) onto a later turn, so it can never re-enter
// the reconcile that opened the channel. Teardown is cooperative: `cancel` calls `Task.cancel()`, and
// the loop stops at its `Task.isCancelled` checkpoint (or when the `for await` throws on cancellation).
//
// The channel is a *pure receiver* (`cancelOnly`): an `AsyncSequence` is output-only. For the *send*
// direction use `Effect.broadcast(_:channel:)`.

extension AsyncSequence where Self: Sendable, Element: Sendable {
    /// Bridges this `AsyncSequence` to a long-lived ``Channel``, mapping each element to an action.
    ///
    /// The sequence is iterated while the channel is in the desired set; leaving that set cancels the
    /// iterating `Task`. A sequence that finishes (or fails) simply stops dispatching — the channel
    /// slot stays registered until the state stops implying it, then the no-op `cancel` runs.
    ///
    /// - Parameters:
    ///   - id: The channel key — the registry slot the subscription occupies.
    ///   - lifetime: ``Channel/Lifetime`` — `.permanent` (default) keeps iterating across state
    ///     changes; `.ephemeral(resetKey:)` restarts the iteration whenever the key changes.
    ///   - transform: Maps each `Element` to an `Action`.
    /// - Returns: A ``Channel`` backed by this sequence.
    public func asChannel<Action: Sendable>(
        id: some Hashable & Sendable,
        lifetime: Channel<Action>.Lifetime = .permanent,
        _ transform: @escaping @Sendable (Element) -> Action
    ) -> Channel<Action> {
        Channel(id: id, lifetime: lifetime) { dispatch in
            let task = Task {
                do {
                    for try await element in self {
                        if Task.isCancelled { return }
                        dispatch(transform(element))
                    }
                } catch {
                    // Cancellation or a failing sequence: stop iterating. Nothing to dispatch — use a
                    // `Result`-mapped sequence upstream if a failure needs to surface as an action.
                }
            }
            return .cancelOnly { task.cancel() }
        }
    }
}
