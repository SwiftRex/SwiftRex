#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension SwiftRex.SubjectType {
    public init(passthroughSubject: PassthroughSubject<Element, ErrorType>) {
        self.init(
            publisher: passthroughSubject.asPublisherType(),
            subscriber: passthroughSubject.asSubscriberType()
        )
    }
}

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension SwiftRex.SubjectType {
    public static func combine() -> SwiftRex.SubjectType<Element, ErrorType> {
        .init(passthroughSubject: PassthroughSubject<Element, ErrorType>())
    }
}

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension PassthroughSubject {
    public func asSubscriberType() -> SubscriberType<Output, Failure> {
        SubscriberType<Output, Failure>.combine(subject: self)
    }
}
#endif
