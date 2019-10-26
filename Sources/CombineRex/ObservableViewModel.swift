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
public final class ObservableViewModel<ViewAction, ViewState>: StoreType, ObservableObject {
    @Published public var state: ViewState
    public let statePublisher: UnfailablePublisherType<ViewState>
    private var cancellableBinding: AnyCancellable!
    private var viewStore: ViewStore<ViewAction, ViewState>

    public func dispatch(_ action: ViewAction) {
        viewStore.dispatch(action)
    }

    public init(initialState: ViewState,
                viewStore: ViewStore<ViewAction, ViewState>,
                emitsValue: ShouldEmitValue<ViewState>) {
        self.state = initialState
        self.viewStore = viewStore
        self.statePublisher = viewStore.statePublisher.removeDuplicates(by: emitsValue.shouldRemove).asPublisherType()
        cancellableBinding = statePublisher.assign(to: \.state, on: self)
    }
}

extension ObservableViewModel where ViewState: Equatable {
    public convenience init(initialState: ViewState, viewStore: ViewStore<ViewAction, ViewState>) {
        self.init(initialState: initialState,
                  viewStore: viewStore,
                  emitsValue: .whenDifferent)
    }
}

extension StoreType {
    public func view<ViewAction, ViewState>(
        action viewActionToGlobalAction: @escaping (ViewAction) -> ActionType?,
        state globalStateToViewState: @escaping (StateType) -> ViewState,
        initialState: ViewState,
        emitsValue: ShouldEmitValue<ViewState>) -> ObservableViewModel<ViewAction, ViewState> {
        let viewStore = self.view(
            action: viewActionToGlobalAction,
            state: { (globalStatePublisher: UnfailablePublisherType<StateType>) -> UnfailablePublisherType<ViewState> in
                globalStatePublisher.map(globalStateToViewState).asPublisherType()
            }
        )

        return .init(initialState: initialState, viewStore: viewStore, emitsValue: emitsValue)
    }

    public func view<ViewAction, ViewState: Equatable>(
        action: @escaping (ViewAction) -> ActionType?,
        state: @escaping (StateType) -> ViewState,
        initialState: ViewState) -> ObservableViewModel<ViewAction, ViewState> {
        view(action: action, state: state, initialState: initialState, emitsValue: .whenDifferent)
    }
}
#endif
