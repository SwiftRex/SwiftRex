import Foundation

public struct SubscriberType<Element, ErrorType: Error> {
    public let onValue: (Element) -> Void
    public let onCompleted: (ErrorType?) -> Void
    public let onSubscribe: (SubscriptionType) -> Void
    public init(onValue: ((Element) -> Void)? = nil,
                onCompleted: ((ErrorType?) -> Void)? = nil,
                onSubscribe: ((SubscriptionType) -> Void)? = nil) {
        self.onValue = onValue ?? { _ in }
        self.onCompleted = onCompleted ?? { _ in }
        self.onSubscribe = onSubscribe ?? { _ in }
    }

    public func assertNoFailure() -> SubscriberType<Element, Never> {
        .init(
            onValue: self.onValue,
            onCompleted: { _ in self.onCompleted(nil) },
            onSubscribe: self.onSubscribe
        )
    }
}

public typealias UnfailableSubscriberType<Element> = SubscriberType<Element, Never>

public struct PublisherType<Element, ErrorType: Error> {
    public let subscribe: (SubscriberType<Element, ErrorType>) -> SubscriptionType
    public init(subscribe: @escaping (SubscriberType<Element, ErrorType>) -> SubscriptionType) {
        self.subscribe = subscribe
    }

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

public typealias UnfailablePublisherType<Element> = PublisherType<Element, Never>

public protocol SubscriptionType {
    func unsubscribe()
}

extension SubscriptionType {
    public func cancelled<SC: SubscriptionCollection>(by subscriptionCollection: inout SC) {
        subscriptionCollection += self
    }

    public func cancelled(by subscriptionCollection: inout SubscriptionCollection) {
        subscriptionCollection += self
    }
}

public protocol SubscriptionCollection {
    mutating func store(subscription: SubscriptionType)
}

func += (_ lhs: inout SubscriptionCollection, _ rhs: SubscriptionType) {
    lhs.store(subscription: rhs)
}

func += <SC: SubscriptionCollection>(_ lhs: inout SC, _ rhs: SubscriptionType) {
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
