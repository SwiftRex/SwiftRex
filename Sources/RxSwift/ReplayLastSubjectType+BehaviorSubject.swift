import Foundation
import RxSwift
import SwiftRex

extension ReplayLastSubjectType where ErrorType == Error {
    public init(behaviorSubject: BehaviorSubject<Element>) {
        self.publisher = behaviorSubject.asPublisher()
        self.subscriber = behaviorSubject.asSubscriber()
        self.value = { try! behaviorSubject.value() }
    }
}

extension ReplayLastSubjectType where ErrorType == Never {
    public init(behaviorSubject: BehaviorSubject<Element>) {
        self.publisher = behaviorSubject.asPublisher().assertNoFailure()
        self.subscriber = behaviorSubject.asSubscriber().assertNoFailure()
        self.value = { try! behaviorSubject.value() }
    }

    public static func rx(initialValue: Element) -> ReplayLastSubjectType {
        let behaviorSubject = BehaviorSubject<Element>(value: initialValue)
        return .init(behaviorSubject: behaviorSubject)
    }
}
