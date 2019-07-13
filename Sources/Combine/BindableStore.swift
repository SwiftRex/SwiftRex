import Combine
import Foundation
import SwiftRex
import SwiftUI

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
public final class BindableStore<StateType>: StoreBase<StateType>, BindableObject {
    public let didChange: AnyPublisher<Void, Never>
    public let state: StateProxy

    public init<M: Middleware>(initialState: StateType, reducer: Reducer<StateType>, middleware: M)
        where M.StateType == StateType {
            let subject = CurrentValueSubject<StateType, Never>(initialState)
            didChange = subject.map { _ in }.eraseToAnyPublisher()
            state = StateProxy(currentValue: { subject.value })
            super.init(subject: ReplayLastSubjectType(currentValueSubject: subject), reducer: reducer, middleware: middleware)
    }

    @dynamicMemberLookup
    public struct StateProxy {
        private let currentValue: () -> StateType

        init(currentValue: @escaping () -> StateType) {
            self.currentValue = currentValue
        }

        public subscript<T>(dynamicMember keyPath: KeyPath<StateType, T>) -> T {
            currentValue()[keyPath: keyPath]
        }
    }
}
