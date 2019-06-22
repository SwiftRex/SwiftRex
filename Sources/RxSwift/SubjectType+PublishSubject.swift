import Foundation
import RxSwift
import SwiftRex

extension SubjectType where ErrorType == Error {
    public init(publishSubject: PublishSubject<Element>) {
        self.publisher = publishSubject.asPublisher()
        self.subscriber = publishSubject.asSubscriber()
    }
}

extension SubjectType where ErrorType == Never {
    public init(publishSubject: PublishSubject<Element>) {
        self.publisher = publishSubject.asPublisher().assertNoFailure()
        self.subscriber = publishSubject.asSubscriber().assertNoFailure()
    }

    public static func rx() -> SubjectType {
        let publishSubject = PublishSubject<Element>()
        return .init(publishSubject: publishSubject)
    }
}
