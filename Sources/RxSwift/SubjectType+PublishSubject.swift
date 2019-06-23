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
    public init(publishSubject: PublishSubject<Element>) {
        self.init(
            publisher: publishSubject.asPublisher().assertNoFailure(),
            subscriber: publishSubject.asSubscriber().assertNoFailure()
        )
    }

    public static func rx() -> SwiftRex.SubjectType<Element, Error> {
        let publishSubject = PublishSubject<Element>()
        return .init(publishSubject: publishSubject)
    }
}
