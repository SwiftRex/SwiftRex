// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// `on` overloads that match an action case and reduce state WITHOUT dispatching (the
// no-dispatch counterpart of the `on(…, dispatch:, reduce:)` family in Behavior+Bridge).
extension Behavior {
    /// Matches a `Prism` and runs a state mutation with no dispatch.
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        reduce: @escaping @Sendable (T, inout State) -> Void
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard let value = prism.preview(action) else { return .doNothing }
            return .reduce { state in reduce(value, &state) }
        })
    }

    /// Matches a `Prism` and runs a state mutation with no dispatch, guarded by a predicate.
    public func on<T: Sendable>(
        _ prism: Prism<Action, T>,
        reduce: @escaping @Sendable (T, inout State) -> Void,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let value = prism.preview(action) else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return .reduce { state in reduce(value, &state) }
        })
    }

    /// Matches a `Prism` (Void case) and runs a state mutation with no dispatch.
    public func on(
        _ prism: Prism<Action, Void>,
        reduce: @escaping @Sendable (inout State) -> Void
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard prism.preview(action) != nil else { return .doNothing }
            return .reduce(reduce)
        })
    }

    /// Matches a `Prism` (Void case) and runs a state mutation with no dispatch, guarded by a predicate.
    public func on(
        _ prism: Prism<Action, Void>,
        reduce: @escaping @Sendable (inout State) -> Void,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard prism.preview(action) != nil else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return .reduce(reduce)
        })
    }

    /// Matches a key path and runs a state mutation with no dispatch.
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        reduce: @escaping @Sendable (T, inout State) -> Void
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard let value = action[keyPath: extract] else { return .doNothing }
            return .reduce { state in reduce(value, &state) }
        })
    }

    /// Matches a key path and runs a state mutation with no dispatch, guarded by a predicate.
    public func on<T: Sendable>(
        _ extract: KeyPath<Action, T?>,
        reduce: @escaping @Sendable (T, inout State) -> Void,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard let value = action[keyPath: extract] else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return .reduce { state in reduce(value, &state) }
        })
    }

    /// Matches a key path (Void case) and runs a state mutation with no dispatch.
    public func on(
        _ extract: KeyPath<Action, Void?>,
        reduce: @escaping @Sendable (inout State) -> Void
    ) -> Self {
        .combine(self, Behavior { action, _ in
            guard action[keyPath: extract] != nil else { return .doNothing }
            return .reduce(reduce)
        })
    }

    /// Matches a key path (Void case) and runs a state mutation with no dispatch, guarded by a predicate.
    public func on(
        _ extract: KeyPath<Action, Void?>,
        reduce: @escaping @Sendable (inout State) -> Void,
        when condition: @escaping @Sendable (State) -> Bool
    ) -> Self {
        .combine(self, Behavior { action, context in
            guard action[keyPath: extract] != nil else { return .doNothing }
            guard let state = context.stateBefore, condition(state) else { return .doNothing }
            return .reduce(reduce)
        })
    }
}
