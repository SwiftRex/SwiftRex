import CoreFP

extension Middleware {
    /// Wraps this middleware as a `Behavior` with an identity reducer (no state mutation).
    ///
    /// Bridges ``MiddlewareReader`` to ``Consequence/effect``: the `@MainActor @Sendable` effect
    /// closure calls `mReader.run(ctx)` directly — no `assumeIsolated` workaround needed because
    /// the closure itself is `@MainActor`.
    public var asBehavior: Behavior<Action, State, Environment> {
        Behavior { action, stateAccess in
            let mReader = self.handle(action, stateAccess)
            return Consequence(
                mutation: .identity,
                effect: { env in
                    mReader.run(MiddlewareEnvironment(
                        environment: env,
                        stateAccess: { stateAccess.snapshotState() }
                    ))
                }
            )
        }
    }
}
