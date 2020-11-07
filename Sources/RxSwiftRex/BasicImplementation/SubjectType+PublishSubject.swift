import Foundation
import RxSwift
import SwiftRex

extension SwiftRex.SubjectType where ErrorType == Error {
    public init(publishSubject: PublishSubject<Element>) {
        self.init(
            publisher: publishSubject.asPublisherType(),
            subscriber: publishSubject.asSubscriberType()
        )
    }
}

extension SwiftRex.SubjectType where ErrorType == Never {
    public init(unfailablePublishSubject: PublishSubject<Element>) {
        self.init(
            publisher: unfailablePublishSubject.asPublisherType().assertNoFailure(),
            subscriber: unfailablePublishSubject.asSubscriberType().assertNoFailure()
        )
    }
}

extension SwiftRex.SubjectType {
    public static func rx() -> SwiftRex.SubjectType<Element, Error> {
        .init(publishSubject: PublishSubject<Element>())
    }
}
