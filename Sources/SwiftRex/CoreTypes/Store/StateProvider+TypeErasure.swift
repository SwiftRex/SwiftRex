/**
 `AnyStateProvider` erases the protocol `StateProvider`, which defines a entities able to offer state publishers (Combine Publisher, RxSwift
 Observable, ReactiveSwift SignalProducer) of certain `StateType`, so everybody can observe the global state changes through this container. Usually
 a `Store` will implement that, but it can also be a `StoreProjection` with a state that is derived from the global source-of-truth.

 The only protocol requirement is to offer a property `statePublisher` that will allow other entities to subscribe to state changes and react to
 those.
*/
public struct AnyStateProvider<StateType>: StateProvider {
    private let publisher: UnfailablePublisherType<StateType>

    public init<S: StateProvider>(_ realProvider: S) where S.StateType == StateType {
        self.init(realProvider.statePublisher)
    }

    public init(_ publisher: UnfailablePublisherType<StateType>) {
        self.publisher = publisher
    }

    public var statePublisher: UnfailablePublisherType<StateType> {
        publisher
    }
}

extension StateProvider {
    public func eraseToAnyStateProvider() -> AnyStateProvider<StateType> {
        AnyStateProvider(self)
    }
}
