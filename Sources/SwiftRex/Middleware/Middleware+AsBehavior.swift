// SPDX-License-Identifier: Apache-2.0

import CoreFP

extension Middleware {
    /// Wraps this middleware as a `Behavior` with an identity reducer (no state mutation).
    ///
    /// A `Middleware` *is* a `Behavior` with no mutations — it shares the same ``Consequence`` model,
    /// so this just rewraps the consequence list (effect-producing reactions plus supervisions).
    public var asBehavior: Behavior<Action, State, Environment> {
        Behavior(consequences: consequences)
    }
}
