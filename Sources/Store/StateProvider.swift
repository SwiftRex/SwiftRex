import RxSwift

/**
 `StateProvider` defines a protocol for an `ObservableType` of `StateType`, so everybody can observe the global state changes through this container. Usually a `Store`.
 */
public protocol StateProvider: ObservableType {

    /// The elements in the ObservableType sequence, which is expected to be the `StateType` (the app global state)
    typealias StateType = E
}
