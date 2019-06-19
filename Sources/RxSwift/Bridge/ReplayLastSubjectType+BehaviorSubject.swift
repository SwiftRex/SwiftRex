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
