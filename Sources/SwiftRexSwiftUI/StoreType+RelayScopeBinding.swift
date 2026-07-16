// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import SwiftRex
import SwiftUI

// The ``Relay/Scope`` two-way binding — the vocabulary-consistent form of ``StoreType/binding(_:set:)``.
// Its coupling is the binding sibling of the collection lanes' shared `ID`: here the action lane and the
// state lane share a **value type** `T` (`Action.L == State.L`). The state lane **reads** the slice (`get`),
// the action lane **embeds** the new value (`review`), and — as with every store binding — the write
// round-trips through a dispatched action, so the reducer stays the only writer.

extension StoreType {
    /// A two-way `Binding<T>` through a ``Relay/Scope`` whose action lane embeds and state lane reads the
    /// **same** value type (`Action.L == State.L`). `get` reads the state slice; `set` dispatches the
    /// embedded action.
    ///
    /// ```swift
    /// TextField("Name", text: store.binding(.action(ViewAction.prism.setName).state(\.name)))
    /// ```
    @MainActor
    public func binding<A, S, E>(
        _ scope: Relay.Scope<A, S, E>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<A.L>
    where
        A: Relay.ActionAxis.EmbedsProtocol,
        S: Relay.StateAxis.ReadsProtocol,
        E: Relay.EnvironmentAxis.Transformation,
        A.G == Action, S.G == State, A.L == S.L {
        Binding(
            get: { scope.state.get(self.state) },
            set: { self.dispatch(scope.action.review($0), source: ActionSource(file: file, function: function, line: line)) }
        )
    }
}
#endif
