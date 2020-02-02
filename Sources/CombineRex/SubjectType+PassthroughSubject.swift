import Combine
import Foundation
import SwiftRex

extension SwiftRex.SubjectType {
    public init(passthroughSubject: PassthroughSubject<Element, ErrorType>) {
        self.init(
            publisher: passthroughSubject.asPublisherType(),
            subscriber: passthroughSubject.asSubscriberType()
        )
    }
}

extension SwiftRex.SubjectType {
    public static func combine() -> SwiftRex.SubjectType<Element, ErrorType> {
        .init(passthroughSubject: PassthroughSubject<Element, ErrorType>())
    }
}

extension PassthroughSubject {
    public func asSubscriberType() -> SubscriberType<Output, Failure> {
        SubscriberType<Output, Failure>.combine(subject: self)
    }
}
