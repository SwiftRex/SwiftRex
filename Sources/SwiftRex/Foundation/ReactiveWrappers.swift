import Foundation

/// Abstraction over subscriber/observer types from reactive frameworks.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public struct SubscriberType<Element, ErrorType: Error> {
    /// Closure to handle new values received
    public let onValue: (Element) -> Void

    /// Closure to handle completion, which has an optional error in case the completion happened due to an error being emitted
    public let onCompleted: (ErrorType?) -> Void

    /// Closure to handle subscription event
    public let onSubscribe: (SubscriptionType) -> Void

    /// Protocol-witness of a subscriber. Configure the behaviour of this wrapper from a concrete implementation from your favourite reactive
    /// framework.
    /// - Parameters:
    ///   - onValue: Closure to handle new values received
    ///   - onCompleted: Closure to handle completion, which has an optional error in case the completion happened due to an error being emitted
    ///   - onSubscribe: Closure to handle subscription event
    public init(onValue: ((Element) -> Void)? = nil,
                onCompleted: ((ErrorType?) -> Void)? = nil,
                onSubscribe: ((SubscriptionType) -> Void)? = nil) {
        self.onValue = onValue ?? { _ in }
        self.onCompleted = onCompleted ?? { _ in }
        self.onSubscribe = onSubscribe ?? { _ in }
    }

    /// Transforms any subscriber into a Unfailable subscriber with the same element type. After calling this method, a subscriber will be derived
    /// and it won't accept publishers that can fail.
    public func assertNoFailure() -> SubscriberType<Element, Never> {
        .init(
            onValue: self.onValue,
            onCompleted: { _ in self.onCompleted(nil) },
            onSubscribe: self.onSubscribe
        )
    }
}

/// Abstraction over subscriber/observer types from reactive frameworks.
/// For this specific case, the failure/error is `Never`, meaning that this subscriber can only subscribe to publishers that don't emit errors.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public typealias UnfailableSubscriberType<Element> = SubscriberType<Element, Never>

/// Abstraction over publisher/observable/signal producer types from reactive frameworks.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public struct PublisherType<Element, ErrorType: Error> {
    public let subscribe: (SubscriberType<Element, ErrorType>) -> SubscriptionType
    public init(subscribe: @escaping (SubscriberType<Element, ErrorType>) -> SubscriptionType) {
        self.subscribe = subscribe
    }

    /// Transforms any publishers into a Unfailable publisher with the same element type. After calling this method, a publisher will be derived
    /// and it won't emit failures or error. In case the upstream emits an error, a `fatalError` will be executed, so be careful when using this
    /// operator.
    public func assertNoFailure() -> PublisherType<Element, Never> {
        .init { subscriber in
            self.subscribe(SubscriberType<Element, ErrorType>(
                onValue: subscriber.onValue,
                onCompleted: { error in
                    if let error = error { fatalError(error.localizedDescription) }
                    subscriber.onCompleted(nil)
                },
                onSubscribe: subscriber.onSubscribe
            ))
        }
    }

    /// Maps elements emitted by the upstream into a new element type, given by the transform function provided by you
    /// - Parameter transform: a function that transforms each element emitted by the upstream into a new element
    /// - Returns: a derived publisher that emits values of the new type, by applying the transform function provided by you
    public func map<NewElement>(_ transform: @escaping (Element) -> NewElement) -> PublisherType<NewElement, ErrorType> {
        .init { subscriber in
            self.subscribe(
                .init(
                    onValue: { subscriber.onValue(transform($0)) },
                    onCompleted: subscriber.onCompleted,
                    onSubscribe: subscriber.onSubscribe
                )
            )
        }
    }
}

/// Abstraction over publisher/observable/signal producer types from reactive frameworks.
/// For this specific case, the failure/error is `Never`, meaning that this publisher can't emit error.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public typealias UnfailablePublisherType<Element> = PublisherType<Element, Never>

/// Abstraction over subscription types from reactive frameworks.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public protocol SubscriptionType {
    /// Stops the observation and clean up all resources
    func unsubscribe()
}

extension SubscriptionType {
    /// Allow to add a subscription to a subscription collection, which is an abstraction for `DisposeBag` or `Set<AnyCancellable` depending on your
    /// chosen reactive framework
    /// - Parameter subscriptionCollection: an abstraction for `DisposeBag` or `Set<AnyCancellable` depending on your chosen reactive framework
    public func cancelled<SC: SubscriptionCollection>(by subscriptionCollection: inout SC) {
        subscriptionCollection += self
    }

    /// Allow to add a subscription to a subscription collection, which is an abstraction for `DisposeBag` or `Set<AnyCancellable` depending on your
    /// chosen reactive framework
    /// - Parameter subscriptionCollection: a mutable abstraction for `DisposeBag` or `Set<AnyCancellable` depending on your chosen reactive framework
    public func cancelled(by subscriptionCollection: inout SubscriptionCollection) {
        subscriptionCollection += self
    }
}

/// Abstraction over subscription collection (`DisposeBag` or `Set<AnyCancellable` depending on your chosen reactive framework), useful for keeping
/// subscriptions alive while the parent class is alive, binding the lifecycle of subscriptions to the lifecycle of views, view controllers or
/// presenters. Subscriptions added to a subscription collection will be cancelled/disposed automatically once the collection gets deallocated,
/// stopping any pending operation and cleaning up the resources.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public protocol SubscriptionCollection {
    mutating func store(subscription: SubscriptionType)
}

/// Adds a subscription to a collection, so it will get cancelled/disposed automatically once the collection gets deallocated, stopping any pending
/// operation and cleaning up the resources.
/// - Parameters:
///   - lhs: subscription collection
///   - rhs: subscription to be added
func += (_ lhs: inout SubscriptionCollection, _ rhs: SubscriptionType) {
    lhs.store(subscription: rhs)
}

/// Adds a subscription to a collection, so it will get cancelled/disposed automatically once the collection gets deallocated, stopping any pending
/// operation and cleaning up the resources.
/// - Parameters:
///   - lhs: subscription collection
///   - rhs: subscription to be added
func += <SC: SubscriptionCollection>(_ lhs: inout SC, _ rhs: SubscriptionType) {
    lhs.store(subscription: rhs)
}

/// Abstraction over passthrough subject types (`PassthroughSubject`, `PublishSubject`, `Signal`) from reactive frameworks.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public struct SubjectType<Element, ErrorType: Error> {
    /// Upstream publisher that feeds events into this subject
    public let publisher: PublisherType<Element, ErrorType>

    /// Downstream subscriber that subscribes to this subject and will receive events from it
    public let subscriber: SubscriberType<Element, ErrorType>

    /// Creates an abstraction over passthrough subject types (`PassthroughSubject`, `PublishSubject`, `Signal`) from reactive frameworks.
    /// - Parameters:
    ///   - publisher: Upstream publisher that feeds events into this subject
    ///   - subscriber: Downstream subscriber that subscribes to this subject and will receive events from it
    public init(publisher: PublisherType<Element, ErrorType>, subscriber: SubscriberType<Element, ErrorType>) {
        self.publisher = publisher
        self.subscriber = subscriber
    }
}

/// Abstraction over passthrough subject types (`PassthroughSubject`, `PublishSubject`, `Signal`) from reactive frameworks.
/// For this specific case, the failure/error is `Never`, meaning that this subject can't emit error.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public typealias UnfailableSubject<Element> = SubjectType<Element, Never>

/// Abstraction over subject types able to keep the last object (`CurrentValueSubject`, `BehaviorSubject`, `MutableProperty`, `Variable`) from
/// reactive frameworks.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public struct ReplayLastSubjectType<Element, ErrorType: Error> {
    /// Upstream publisher that feeds data into this subject
    public let publisher: PublisherType<Element, ErrorType>

    /// Downstream subscriber that subscribes to this subject and will receive events from it
    public let subscriber: SubscriberType<Element, ErrorType>

    /// Reads the most recent element emitted by this subject. This subject can be seen as a variable in stateful programming style, it holds one
    /// value that can be read at any point using a getter function `() -> Element`. Useful for bridging with the imperative world.
    public var value: () -> Element

    /// Creates an abstraction over subject types able to keep the last object (`CurrentValueSubject`, `BehaviorSubject`, `MutableProperty`,
    /// `Variable`) from reactive frameworks.
    /// - Parameters:
    ///   - publisher: Upstream publisher that feeds events into this subject
    ///   - subscriber: Downstream subscriber that subscribes to this subject and will receive events from it
    ///   - value: Reads the most recent element emitted by this subject. This subject can be seen as a variable in stateful programming style, it
    ///            holds one value that can be read at any point using a getter function `() -> Element`. Useful for bridging with the imperative
    ///            world.
    public init(
        publisher: PublisherType<Element, ErrorType>,
        subscriber: SubscriberType<Element, ErrorType>,
        value: @escaping () -> Element) {
        self.publisher = publisher
        self.subscriber = subscriber
        self.value = value
    }
}

extension ReplayLastSubjectType {
    /// Atomically mutate this subject's value in a closure where you can read and write the current element value
    /// - Parameter action: read and write the current value atomically, and optionally return something
    /// - Returns: returns whatever is returned by the action closure, allowing to chain operations
    @discardableResult
    public func mutate<Result>(_ action: (inout Element) -> Result) -> Result {
        var currentValue = value()
        let result = action(&currentValue)
        subscriber.onValue(currentValue)
        return result
    }

    /// Atomically mutate this subject's value in a closure where you can read and write the current element value
    /// Before the mutation, a condition will be evaluated and the mutation will only happen when the result of this evaluation returns `true`.
    /// This allows you to simulate the mutation before executing it.
    /// - Parameters:
    ///   - condition: a predicate that, after simulating the mutation, allows you to decide if it should happen or not
    ///   - action: read and write the current value atomically, and optionally return something
    /// - Returns: returns whatever is returned by the action closure, allowing to chain operations
    @discardableResult
    public func mutate<Result>(when condition: @escaping (Result) -> Bool, action: (inout Element) -> Result) -> Result {
        var currentValue = value()
        let result = action(&currentValue)
        guard condition(result) else { return result }
        subscriber.onValue(currentValue)
        return result
    }
}

/// Abstraction over subject types able to keep the last object (`CurrentValueSubject`, `BehaviorSubject`, `MutableProperty`, `Variable`) from
/// reactive frameworks.
/// For this specific case, the failure/error is `Never`, meaning that this subject can't emit error.
/// This abstraction uses concept similar to type-erasure or protocol witness pattern, wrapping the behaviour of concrete implementations and
/// delegating to them once the wrapper funcions are called.
public typealias UnfailableReplayLastSubjectType<Element> = ReplayLastSubjectType<Element, Never>
