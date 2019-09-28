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
public final class BindableStore<ActionType, StateType>: StoreBase<ActionType, StateType>, ObservableObject {
    @Published public var state: StateType
    private var cancellableBinding: AnyCancellable!

    public init<M: Middleware>(initialState: StateType, reducer: Reducer<ActionType, StateType>, middleware: M)
        where M.ActionType == ActionType, M.StateType == StateType {
        _state = .init(initialValue: initialState)
        let subject = UnfailableReplayLastSubjectType.combine(initialValue: initialState)
        super.init(subject: subject,
                   reducer: reducer,
                   middleware: middleware)
        cancellableBinding = subject.publisher.sink { [unowned self] newValue in
            self.state = newValue
        }
    }
}
#endif
