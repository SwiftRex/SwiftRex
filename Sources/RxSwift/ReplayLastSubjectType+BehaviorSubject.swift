import Foundation
import RxSwift
import SwiftRex

extension ReplayLastSubjectType where ErrorType == Error {
    public init(behaviorSubject: BehaviorSubject<Element>) {
        self.init(
            publisher: behaviorSubject.asPublisher(),
            subscriber: behaviorSubject.asSubscriber(),
            value: { try! behaviorSubject.value() }
        )
    }
}

extension ReplayLastSubjectType where ErrorType == Never {
    public init(behaviorSubject: BehaviorSubject<Element>) {
        self.init(
            publisher: behaviorSubject.asPublisher().assertNoFailure(),
            subscriber: behaviorSubject.asSubscriber().assertNoFailure(),
            value: { try! behaviorSubject.value() }
        )
    }

    public static func rx(initialValue: Element) -> ReplayLastSubjectType<Element, Error> {
        let behaviorSubject = BehaviorSubject<Element>(value: initialValue)
        return .init(behaviorSubject: behaviorSubject)
    }
}
