import SwiftRex

extension StoreType {
    /// Lifts any `StoreType` into an `ObservableObjectStore` for use with `@StateObject`
    /// or `@ObservedObject` on iOS 15+.
    ///
    /// ```swift
    /// @StateObject var vm = appStore
    ///     .projection(action: AppAction.counter, state: \.counterState)
    ///     .buffer()
    ///     .asObservableObject()
    /// ```
    public func asObservableObject() -> ObservableObjectStore<Action, State> {
        ObservableObjectStore(self)
    }
}

extension StoreType {
    /// Lifts any `StoreType` into an `ObservableStore` for use with `@State` on iOS 17+.
    ///
    /// ```swift
    /// @State var vm = appStore
    ///     .projection(action: AppAction.counter, state: \.counterState)
    ///     .buffer()
    ///     .asObservableStore()
    /// ```
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    public func asObservableStore() -> ObservableStore<Action, State> {
        ObservableStore(self)
    }
}
