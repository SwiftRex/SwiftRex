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
    private var storeProjection: StoreProjection<ViewAction, ViewState>

    public func dispatch(_ action: ViewAction) {
        storeProjection.dispatch(action)
    }

    public init(initialState: ViewState,
                storeProjection: StoreProjection<ViewAction, ViewState>,
                emitsValue: ShouldEmitValue<ViewState>) {
        self.state = initialState
        self.storeProjection = storeProjection
        self.statePublisher = storeProjection.statePublisher.removeDuplicates(by: emitsValue.shouldRemove).asPublisherType()
        cancellableBinding = statePublisher.assign(to: \.state, on: self)
    }
}

extension ObservableViewModel where ViewState: Equatable {
    public convenience init(initialState: ViewState, storeProjection: StoreProjection<ViewAction, ViewState>) {
        self.init(initialState: initialState,
                  storeProjection: storeProjection,
                  emitsValue: .whenDifferent)
    }
}

extension StoreType {
    public func projection<ViewAction, ViewState>(
        action viewActionToGlobalAction: @escaping (ViewAction) -> ActionType?,
        state globalStateToViewState: @escaping (StateType) -> ViewState,
        initialState: ViewState,
        emitsValue: ShouldEmitValue<ViewState>) -> ObservableViewModel<ViewAction, ViewState> {
        let storeProjection = self.projection(
            action: viewActionToGlobalAction,
            state: { (globalStatePublisher: UnfailablePublisherType<StateType>) -> UnfailablePublisherType<ViewState> in
                globalStatePublisher.map(globalStateToViewState).asPublisherType()
            }
        )

        return .init(initialState: initialState, storeProjection: storeProjection, emitsValue: emitsValue)
    }

    public func projection<ViewAction, ViewState: Equatable>(
        action: @escaping (ViewAction) -> ActionType?,
        state: @escaping (StateType) -> ViewState,
        initialState: ViewState) -> ObservableViewModel<ViewAction, ViewState> {
        projection(action: action, state: state, initialState: initialState, emitsValue: .whenDifferent)
    }
}

#if DEBUG
extension ObservableViewModel {
    /// Mock for using in tests or SwiftUI previews, available in DEBUG mode only
    /// You can use if as a micro-redux for tests and SwiftUI previews, for example:
    /// ```
    /// let mock = ObservableViewModel<(user: String, pass: String, buttonEnabled: Bool), ViewAction>.mock(
    ///     state: (user: "ozzy", pass: "", buttonEnabled: false),
    ///     action: { action, state in
    ///         switch action {
    ///         case let .userChanged(newUser):
    ///             state.user = newUser
    ///             state.buttonEnabled = !state.user.isEmpty && !state.pass.isEmpty
    ///         case let .passwordChanged(newPass):
    ///             state.pass = newPass
    ///             state.buttonEnabled = !state.user.isEmpty && !state.pass.isEmpty
    ///         case .buttonTapped:
    ///             print("Button tapped")
    ///         }
    ///     }
    /// )
    /// ```
    /// - Parameter state: Initial state mock
    /// - Parameter action: a simple reducer function, of type `(ActionType, inout StateType) -> Void`, useful if
    ///                     you want to use in SwiftUI live previews and quickly change an UI property when a
    ///                     button is tapped, for example. It's like a micro-redux for tests and SwiftUI previews.
    ///                     Defaults to do nothing.
    /// - Returns: a very simple ObservableViewModel mock, that you can inject in your SwiftUI View for tests or
    ///            live preview.
    public static func mock(state: StateType, action: (@escaping (ActionType, inout StateType) -> Void) = { _, _ in })
        -> ObservableViewModel<ActionType, StateType> {
        let subject = CurrentValueSubject<StateType, Never>(state)

        let storeProjection = StoreProjection<ActionType, StateType>(
            action: {
                var state = subject.value
                action($0, &state)
                subject.send(state)
            },
            state: subject.asPublisherType()
        )

        return .init(initialState: state, storeProjection: storeProjection, emitsValue: .always)
    }
}
#endif

#endif
