import Foundation
import RxSwift
import SwiftRex

extension SwiftRex.SubjectType where ErrorType == Error {
    public init(publishSubject: PublishSubject<Element>) {
        self.init(
            publisher: publishSubject.asPublisher(),
            subscriber: publishSubject.asSubscriber()
        )
    }
}

extension SwiftRex.SubjectType where ErrorType == Never {
    public init(unfailablePublishSubject: PublishSubject<Element>) {
        self.init(
            publisher: unfailablePublishSubject.asPublisher().assertNoFailure(),
            subscriber: unfailablePublishSubject.asSubscriber().assertNoFailure()
        )
    }
}

extension SwiftRex.SubjectType {
    public static func rx() -> SwiftRex.SubjectType<Element, Error> {
        .init(publishSubject: PublishSubject<Element>())
    }
}
