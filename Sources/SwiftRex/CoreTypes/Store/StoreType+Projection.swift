import Foundation

/**

 Not necessarily a store implementation means that this entity holds the source-of-truth of an app. The source-of-truth
 should be single a centralized store, where all the state is held. But your Views and ViewControllers not necessarily
 need to access this main Store directly, they could, instead, access some "proxy" store that simply intermediates
 all actions (inputs) and state change notifications (outputs), without actually holding the truth. For more information
 on that please check `StoreProjection`, and compare it to `ReduxStoreBase`.

 Well, this unlocks several possibilities like having "Store Projections" or "View Stores", which act somehow like
 presenters (in MVP pattern) or ViewModels (in MVVM pattern), because this layer can be seen as a simple transformation
 of states and actions. The view store will transform State into View State by, for example, applying NumberFormatter or
 DateFormatter into numbers and dates from your state and generating strings to be shown in UI labels or text fields.
 You can picture that as dozens of small functions, transforming each property individually, or you can group all the
 properties in a view item, or view state, containing lots of strings to be used by UI controls, and then the whole
 process is a single function from `(State) -> ViewState`. In the other direction, you probably want to map UI events
 like scrolling, button taps, toggle changes and view lifecycle events (did load, will appear, foreground) into app
 actions like save a form, load next page, add to favorites or reload a list of items. Grouping them in an enum of
 possible events triggered by the user in a certain view, and you may want to map these view actions into app actions:
 `(ViewAction) -> AppAction`.

 Because the `StoreType` protocol is very generic and offers `ActionHandler` and `StateProvider`, we can think of other
 possible implementations like a proxy view store that knows how to reach the main store, but exposes to a view only
 what's relevant for it (`ViewState` and `ViewAction`), at the same time it knows how to map `(State) -> ViewState` and
 `(ViewAction) -> AppAction`. These two transformations are used every time a view dispatches a view action or a state
 changes and notifies all subscribers.

 Some store implementations will glue all the parts together and become responsible for being its responsibility is
 being a proxy to the non-Redux world. For that reason, it's correct to say that a `StoreType` is the single point of
 contact with `UIKit` and it's a class that you want to inject as a dependency on all the ViewControllers, either as one
 single dependency or, preferably, a dependency for each of its protocols - `EventHandler` and `StateProvider` -, both
 eventually pointing to the same instance.

 */
public typealias StoreProjection<ViewAction, ViewState> = AnyStoreType<ViewAction, ViewState>

extension StoreType {
    public func projection<ViewAction, ViewState>(
        action viewActionToGlobalAction: @escaping (ViewAction) -> ActionType?,
        state globalStateToViewState: @escaping (StateType) -> ViewState
    ) -> StoreProjection<ViewAction, ViewState> {
        .init(
            action: { newAction, dispatcher in
                guard let oldAction = viewActionToGlobalAction(newAction) else { return }
                self.dispatch(oldAction, from: dispatcher)
            },
            state: self.statePublisher.map(globalStateToViewState)
        )
    }
}
