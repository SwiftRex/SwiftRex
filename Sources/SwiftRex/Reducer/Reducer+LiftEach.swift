// SPDX-License-Identifier: Apache-2.0

import CoreFP
import DataStructure

// MARK: - liftEach (broadcast — Traversal)

//
// `liftEach` is the 0..n sibling of ``Reducer/liftCollection(action:stateContainer:)-``: where
// `liftCollection` routes a global action to ONE element (selected by id), `liftEach` applies the
// resolved local action to EVERY focus of a `Traversal` at once.
//
// A `Reducer` carries no effects, so the broadcast is just `Traversal.lift` of the per-element
// reduce: each focus gets the same `EndoMut<StateType>` applied to its own state, zero-copy on
// the array buffer. (Per-element effect-id scoping only matters for `Behavior`/`Middleware`.)

extension Reducer {
    /// Primitive — broadcast across a `Traversal`, with a `Lens` state container.
    ///
    /// - Parameters:
    ///   - action: Resolves a global action into the local `ActionType` to broadcast. Returns
    ///     `nil` for global actions this reducer should ignore (a no-op).
    ///   - each: The traversal selecting every target focus inside its container.
    ///   - stateContainer: A `Lens` from the global state to the container.
    public func liftEach<GA: Sendable, GS: Sendable, Container: Sendable>(
        action: @escaping @Sendable (GA) -> ActionType?,
        each: Traversal<Container, StateType>,
        stateContainer: Lens<GS, Container>
    ) -> Reducer<GA, GS> {
        .reduce { globalAction in
            guard let local = action(globalAction) else { return .identity }
            return stateContainer.compose(each).lift(self.reduce(local))
        }
    }

    /// Primitive — broadcast across a `Traversal`, with a `WritableKeyPath` state container.
    public func liftEach<GA: Sendable, GS: Sendable, Container: Sendable>(
        action: @escaping @Sendable (GA) -> ActionType?,
        each: Traversal<Container, StateType>,
        stateContainer: WritableKeyPath<GS, Container>
    ) -> Reducer<GA, GS> {
        liftEach(action: action, each: each, stateContainer: lens(stateContainer))
    }
}

// MARK: - liftEach (every element of a collection)

extension Reducer {
    /// Broadcasts to **every** element of a mutable collection. State container via `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable>(
        action: @escaping @Sendable (GA) -> ActionType?,
        stateCollection: WritableKeyPath<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftEach(action: action, each: C.each, stateContainer: lens(stateCollection))
    }

    /// Broadcasts to **every** element of a mutable collection. State container via `Lens`.
    public func liftEach<GA: Sendable, GS: Sendable, C: MutableCollection & Sendable>(
        action: @escaping @Sendable (GA) -> ActionType?,
        stateCollection: Lens<GS, C>
    ) -> Reducer<GA, GS> where C.Element == StateType {
        liftEach(action: action, each: C.each, stateContainer: stateCollection)
    }
}

// MARK: - liftEach (every value of a dictionary)

extension Reducer {
    /// Broadcasts to **every** value of a dictionary. State container via `WritableKeyPath`.
    public func liftEach<GA: Sendable, GS: Sendable, Key: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> ActionType?,
        stateDictionary: WritableKeyPath<GS, [Key: StateType]>
    ) -> Reducer<GA, GS> {
        liftEach(action: action, each: [Key: StateType].eachValue, stateContainer: lens(stateDictionary))
    }

    /// Broadcasts to **every** value of a dictionary. State container via `Lens`.
    public func liftEach<GA: Sendable, GS: Sendable, Key: Hashable & Sendable>(
        action: @escaping @Sendable (GA) -> ActionType?,
        stateDictionary: Lens<GS, [Key: StateType]>
    ) -> Reducer<GA, GS> {
        liftEach(action: action, each: [Key: StateType].eachValue, stateContainer: stateDictionary)
    }
}
