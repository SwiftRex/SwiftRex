import Foundation
import RxSwift
import SwiftRex

extension SubjectType where ErrorType == Error {
    public init(publishSubject: PublishSubject<Element>) {
        self.publisher = publishSubject.asPublisher()
        self.subscriber = publishSubject.asSubscriber()
    }
}
