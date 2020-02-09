/**
 `StateProvider` defines a protocol for entities able to offer state publishers (Combine Publisher, RxSwift Observable,
 ReactiveSwift SignalProducer) of certain `StateType`, so everybody can observe the global state changes through this
 container. Usually a `Store` will implement that, but it can also be a `StoreProjection` with a state that is derived from
 the global source-of-truth.

 The only protocol requirement is to offer a property `statePublisher` that will allow other entities to subscribe to
 state changes and react to those.
 */
public protocol StateProvider {
    /// This can be a global state, or a view state that is a not a source-of-truth but only a struct calculated and
    /// derived from a global source-of-truth, without storage to avoid state inconsistency.
    associatedtype StateType

    /// The state publisher that can be observed by counterparts
    var statePublisher: UnfailablePublisherType<StateType> { get }
}

extension StateProvider {
    public func map<NewStateType>(_ transform: @escaping (StateType) -> NewStateType) -> AnyStateProvider<NewStateType> {
        .init(self.statePublisher.map(transform))
    }
}

// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = StateType
extension StateProvider { }
