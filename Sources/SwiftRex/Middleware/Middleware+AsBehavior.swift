import CoreFP

extension Middleware {
    /// Wraps this middleware as a `Behavior` with an identity reducer (no state mutation).
    public var asBehavior: Behavior<Action, State, Environment> {
        Behavior { action, stateAccess in
            Consequence(mutation: .identity, effect: self.handle(action, stateAccess))
        }
    }
}
