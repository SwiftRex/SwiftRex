import Foundation

/// An app should have a single real Store, holding a single source-of-truth. However, we can "derive" this store to small subsets, called store
/// projections, that will handle either a smaller part of the state or action tree, or even a completely different type of actions and states as
/// long as we can map back-and-forth to the original store types. It won't store anything, only project the original store. For example, a View can
/// define a completely custom View State and View Action, and we can create a ``StoreProjection`` that works on these types, as long as it's backed
/// by a real store which State and Action types can be mapped somehow to the View State and View Action types. The Store Projection will take care
/// of translating these entities.
public typealias StoreProjection<ViewAction, ViewState> = AnyStoreType<ViewAction, ViewState>

extension StoreType {
    /// Creates a subset of the current store by applying any transformation to the State or Action types.
    ///
    /// - Parameters:
    ///   - action: a closure that will transform the View Actions into global App Actions, to be dispatched in the original Store
    ///   - state: a closure that will transform the global App State into the View State, to subscribe the original Store and drive the View upon
    ///            changes
    /// - Returns: a ``StoreProjection`` struct, that uses the original Store under the hood, by applying the required transformations on state and
    ///            action when app state changes or view actions arrive. It doesn't store anything, just proxies the original store.
    public func projection<ViewAction, ViewState>(
        action viewActionToGlobalAction: @escaping (ViewAction) -> ActionType?,
        state globalStateToViewState: @escaping (StateType) -> ViewState
    ) -> StoreProjection<ViewAction, ViewState> {
        .init(
            action: { dispatchedAction in
                guard let globalAction = dispatchedAction.compactMap(viewActionToGlobalAction) else { return }
                self.dispatch(globalAction)
            },
            state: self.statePublisher.map(globalStateToViewState)
        )
    }
}
