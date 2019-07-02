#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

extension ReplayLastSubjectType {
    public init(currentValueSubject: CurrentValueSubject<Element, ErrorType>) {
        self.init(
            publisher: currentValueSubject.asPublisherType(),
            subscriber: SubscriberType(
                onValue: { currentValueSubject.value = $0 },
                onCompleted: { error in
                    currentValueSubject.send(completion: error.map(Subscribers.Completion<ErrorType>.failure) ?? .finished)
                }
            ),
            value: { currentValueSubject.value }
        )
    }

    public static func combine(initialValue: Element) -> ReplayLastSubjectType<Element, ErrorType> {
        let currentValueSubject = CurrentValueSubject<Element, ErrorType>(initialValue)
        return .init(currentValueSubject: currentValueSubject)
    }
}
#endif
