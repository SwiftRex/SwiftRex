import Foundation

public struct SubscriberType<Element, ErrorType: Error> {
    public let onValue: (Element) -> Void
    public let onError: (ErrorType) -> Void
    public init(onValue: @escaping (Element) -> Void = { _ in }, onError: @escaping (ErrorType) -> Void = { _ in }) {
        self.onValue = onValue
        self.onError = onError
    }
}

public typealias UnfailableSubscriberType<Element> = SubscriberType<Element, Never>

public struct PublisherType<Element, ErrorType: Error> {
    public let subscribe: (SubscriberType<Element, ErrorType>) -> Subscription
    public init(subscribe: @escaping (SubscriberType<Element, ErrorType>) -> Subscription) {
        self.subscribe = subscribe
    }
}

public typealias UnfailablePublisherType<Element> = PublisherType<Element, Never>

public protocol Subscription {
    func unsubscribe()
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
    public init(publisher: PublisherType<Element, ErrorType>, subscriber: SubscriberType<Element, ErrorType>, value: @escaping () -> Element) {
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
}

public typealias UnfailableReplayLastSubjectType<Element> = ReplayLastSubjectType<Element, Never>
