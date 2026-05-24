import CoreFP

extension Middleware {
    /// Wraps this middleware as a `Behavior` with an identity reducer (no state mutation).
    ///
    /// Bridges `Reader<Environment, Effect<Action>>` to ``Consequence/effect``: the
    /// `@MainActor @Sendable` effect closure calls `reader.runReader(env)` — valid because
    /// calling a non-isolated `@Sendable` closure from `@MainActor` is always permitted.
    public var asBehavior: Behavior<Action, State, Environment> {
        Behavior { action, stateAccess in
            Consequence(
                mutation: .identity,
                effect: self.handle(action, stateAccess)
            )
        }
    }
}
