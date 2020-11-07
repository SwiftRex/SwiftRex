#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SwiftRex.SubjectType {
    public init(passthroughSubject: PassthroughSubject<Element, ErrorType>) {
        self.init(
            publisher: passthroughSubject.asPublisherType(),
            subscriber: passthroughSubject.asSubscriberType()
        )
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SwiftRex.SubjectType {
    public static func combine() -> SwiftRex.SubjectType<Element, ErrorType> {
        .init(passthroughSubject: PassthroughSubject<Element, ErrorType>())
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PassthroughSubject {
    public func asSubscriberType() -> SubscriberType<Output, Failure> {
        SubscriberType<Output, Failure>.combine(subject: self)
    }
}
#endif
