import CoreFP

extension Middleware {
    /// Wraps this middleware as a `Behavior` with an identity reducer (no state mutation).
    ///
    /// The middleware's `handle` closure is called during phase 1 on `@MainActor`, producing a
    /// `Reader<PostReducerContext<State, Environment>, Effect<Action>>` that the Store runs in
    /// phase 3 after all mutations complete.
    public var asBehavior: Behavior<Action, State, Environment> {
        Behavior(
            units: [
                { action, context in
                    Consequence(mutation: .unchanged, effect: self.handle(action, context))
                }
            ],
            supervise: self.supervise
        )
    }
}
