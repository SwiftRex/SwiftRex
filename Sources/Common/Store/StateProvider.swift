/**
 `StateProvider` defines a protocol for an `ObservableType` of `StateType`, so everybody can observe the global state changes through this container. Usually a `Store`.
 */
public protocol StateProvider {
    associatedtype StateType
    var statePublisher: UnfailablePublisherType<StateType> { get }
}
