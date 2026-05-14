import SwiftRex

#if canImport(Combine)
extension StoreType {
    /// Wraps this store in an ``ObservableObjectStore`` for use with `@StateObject` / `@ObservedObject`.
    ///
    /// Requires iOS 15+ (Combine). The returned wrapper fires `objectWillChange` before each
    /// mutation, keeping SwiftUI animation snapshots accurate.
    ///
    /// Apply ``StoreType/projection(action:state:)`` before calling this method if you need to
    /// narrow the action or state type:
    ///
    /// ```swift
    /// @StateObject var vm = appStore
    ///     .projection(action: AppAction.counter, state: \.counterState)
    ///     .buffer()
    ///     .asObservableObject()
    /// ```
    ///
    /// On iOS 17+ prefer ``asObservableStore()`` for fine-grained `@Observable` tracking.
    ///
    /// - Returns: An ``ObservableObjectStore`` wrapping `self`.
    public func asObservableObject() -> ObservableObjectStore<Action, State> {
        ObservableObjectStore(self)
    }
}
#endif

extension StoreType {
    /// Wraps this store in an ``ObservableStore`` for use with `@State`.
    ///
    /// Requires iOS 17+ / macOS 14+ (`Observation` framework). The returned wrapper uses
    /// `@Observable`'s registrar so only views that read a changed field of `state` re-render.
    ///
    /// Apply ``StoreType/projection(action:state:)`` before calling this method if you need to
    /// narrow the action or state type:
    ///
    /// ```swift
    /// @State var vm = appStore
    ///     .projection(action: AppAction.counter, state: \.counterState)
    ///     .buffer()
    ///     .asObservableStore()
    /// ```
    ///
    /// On iOS 15/16 fall back to ``asObservableObject()``.
    ///
    /// - Returns: An ``ObservableStore`` wrapping `self`.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    public func asObservableStore() -> ObservableStore<Action, State> {
        ObservableStore(self)
    }
}
