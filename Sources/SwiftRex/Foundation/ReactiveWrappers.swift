import Foundation

public struct SubscriberType<Element, ErrorType: Error> {
    public let onValue: (Element) -> Void
    public let onCompleted: (ErrorType?) -> Void
    public init(onValue: ((Element) -> Void)? = nil, onCompleted: ((ErrorType?) -> Void)? = nil) {
        self.onValue = onValue ?? { _ in }
        self.onCompleted = onCompleted ?? { _ in }
    }

    public func assertNoFailure() -> SubscriberType<Element, Never> {
        .init(
            onValue: { value in self.onValue(value) },
            onCompleted: { _ in self.onCompleted(nil) }
        )
    }
}

public typealias UnfailableSubscriberType<Element> = SubscriberType<Element, Never>

public struct PublisherType<Element, ErrorType: Error> {
    public let subscribe: (SubscriberType<Element, ErrorType>) -> Subscription
    public init(subscribe: @escaping (SubscriberType<Element, ErrorType>) -> Subscription) {
        self.subscribe = subscribe
    }

    public func assertNoFailure() -> PublisherType<Element, Never> {
        .init { subscriber in
            self.subscribe(SubscriberType<Element, ErrorType>(
                onValue: subscriber.onValue,
                onCompleted: { error in
                    if let error = error { fatalError(error.localizedDescription) }
                    subscriber.onCompleted(nil)
                }
            ))
        }
    }
}

public typealias UnfailablePublisherType<Element> = PublisherType<Element, Never>

public protocol Subscription {
    func unsubscribe()
}

extension Subscription {
    public func cancelled<SC: SubscriptionCollection>(by subscriptionCollection: inout SC) {
        subscriptionCollection += self
    }

    public func cancelled(by subscriptionCollection: inout SubscriptionCollection) {
        subscriptionCollection += self
    }
}

public protocol SubscriptionCollection {
    mutating func store(subscription: Subscription)
}

func += (_ lhs: inout SubscriptionCollection, _ rhs: Subscription) {
    lhs.store(subscription: rhs)
}

func += <SC: SubscriptionCollection>(_ lhs: inout SC, _ rhs: Subscription) {
    lhs.store(subscription: rhs)
}

public struct SubjectType<Element, ErrorType: Error> {
    public let publisher: PublisherType<Element, ErrorType>
    public let subscriber: SubscriberType<Element, ErrorType>
    public init(publisher: PublisherType<Element, ErrorType>, subscriber: SubscriberType<Element, ErrorType>) {
        self.publisher = publisher
        self.subscriber = subscriber
    }
}

public typealias UnfailableSubject<Element> = SubjectType<Element, Never>

public struct ReplayLastSubjectType<Element, ErrorType: Error> {
    public let publisher: PublisherType<Element, ErrorType>
    public let subscriber: SubscriberType<Element, ErrorType>
    public var value: () -> Element
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
    @discardableResult
    public func mutate<Result>(_ action: (inout Element) -> Result) -> Result {
        var currentValue = value()
        let result = action(&currentValue)
        subscriber.onValue(currentValue)
        return result
    }

    @discardableResult
    public func mutate<Result>(when condition: @escaping (Result) -> Bool, action: (inout Element) -> Result) -> Result {
        var currentValue = value()
        let result = action(&currentValue)
        guard condition(result) else { return result }
        subscriber.onValue(currentValue)
        return result
    }
}

public typealias UnfailableReplayLastSubjectType<Element> = ReplayLastSubjectType<Element, Never>
