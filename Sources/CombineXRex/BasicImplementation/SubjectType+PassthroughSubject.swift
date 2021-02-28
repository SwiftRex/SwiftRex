import CombineX
import CXFoundation
import Foundation
import SwiftRex

extension SwiftRex.SubjectType {
    public init(passthroughSubject: CombineX.PassthroughSubject<Element, ErrorType>) {
        self.init(
            publisher: passthroughSubject.asPublisherType(),
            subscriber: passthroughSubject.asSubscriberType()
        )
    }
}

extension SwiftRex.SubjectType {
    public static func combineX() -> SwiftRex.SubjectType<Element, ErrorType> {
        .init(passthroughSubject: CombineX.PassthroughSubject<Element, ErrorType>())
    }
}

extension CombineX.PassthroughSubject {
    public func asSubscriberType() -> SubscriberType<Output, Failure> {
        SubscriberType<Output, Failure>.combineX(subject: self)
    }
}
