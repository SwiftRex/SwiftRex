#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

/// A Store made to be used in SwiftUI
///
/// All you need is to create a single instance of this class for the whole lifetime of your app and send to your Views
/// using either, object binding:
/// ```
/// // SceneDelegate.swift:
/// ContentView(store: store)
/// // ContentView.swift:
/// @ObjectBinding var store: MainStore
/// ```
///
/// or environment object:
/// ```
/// // SceneDelegate.swift:
/// ContentView().environmentObject(store)
/// // ContentView.swift:
/// @EnvironmentObject var store: MainStore
/// ```
///
/// Either way you can dispatch events:
/// ```
/// Button("Add to List") {
///     self.store.eventHandler.dispatch(MyListEvent.add)
/// }
/// ```
///
/// or present info:
/// ```
/// Text(store.state.currentSearchText)
/// ```
public final class BindableStore<ViewAction, ViewState>: StoreType, ObservableObject {
    @Published public var state: ViewState
    public var statePublisher: UnfailablePublisherType<ViewState> { viewStore.statePublisher }
    private var cancellableBinding: AnyCancellable!
    private var viewStore: ViewStore<ViewAction, ViewState>

    public func dispatch(_ action: ViewAction) {
        viewStore.dispatch(action)
    }

    private init(initialState: ViewState,
                 viewStore: ViewStore<ViewAction, ViewState>,
                 removeDuplicates: @escaping (PublisherType<ViewState, Never>) -> Publishers.RemoveDuplicates<PublisherType<ViewState, Never>>) {
        self.state = initialState
        self.viewStore = viewStore
        cancellableBinding = removeDuplicates(statePublisher).assign(to: \.state, on: self)
    }

    public convenience init(initialState: ViewState,
                            viewStore: ViewStore<ViewAction, ViewState>,
                            removeDuplicates: @escaping (ViewState, ViewState) -> Bool) {
        self.init(initialState: initialState,
                  viewStore: viewStore,
                  removeDuplicates: { $0.removeDuplicates(by: removeDuplicates) })
    }
}

extension BindableStore where ViewState: Equatable {
    public convenience init(initialState: ViewState, viewStore: ViewStore<ViewAction, ViewState>) {
        self.init(initialState: initialState,
                  viewStore: viewStore,
                  removeDuplicates: { $0.removeDuplicates() })

    }
}

extension StoreType {
    public func view<ViewAction, ViewState>(
        action viewActionToGlobalAction: @escaping (ViewAction) -> ActionType?,
        state globalStateToViewState: @escaping (StateType) -> ViewState,
        initialState: ViewState,
        removeDuplicates: @escaping (ViewState, ViewState) -> Bool) -> BindableStore<ViewAction, ViewState> {
        let viewStore = self.view(
            action: viewActionToGlobalAction,
            state: { (globalStatePublisher: UnfailablePublisherType<StateType>) -> UnfailablePublisherType<ViewState> in
                globalStatePublisher.map(globalStateToViewState).asPublisherType()
            }
        )

        return .init(initialState: initialState, viewStore: viewStore, removeDuplicates: removeDuplicates)
    }

    public func view<ViewAction, ViewState: Equatable>(
        action viewActionToGlobalAction: @escaping (ViewAction) -> ActionType?,
        state globalStateToViewState: @escaping (StateType) -> ViewState,
        initialState: ViewState) -> BindableStore<ViewAction, ViewState> {
        let viewStore = self.view(
            action: viewActionToGlobalAction,
            state: { (globalStatePublisher: UnfailablePublisherType<StateType>) -> UnfailablePublisherType<ViewState> in
                globalStatePublisher.map(globalStateToViewState).asPublisherType()
            }
        )

        return .init(initialState: initialState, viewStore: viewStore)
    }
}
#endif
