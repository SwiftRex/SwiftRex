import CombineX
import CXFoundation
import Foundation
import SwiftRex

extension ReplayLastSubjectType {
    public init(currentValueSubject: CombineX.CurrentValueSubject<Element, ErrorType>,
                willChange: ((Element) -> Void)? = nil) {
        self.init(
            publisher: currentValueSubject.asPublisherType(),
            subscriber: SubscriberType(
                onValue: { newValue in
                    willChange?(newValue)
                    currentValueSubject.value = newValue
                },
                onCompleted: { error in
                    currentValueSubject.send(completion: error.map(Subscribers.Completion<ErrorType>.failure) ?? .finished)
                },
                onSubscribe: { subscription in
                    currentValueSubject.send(subscription: subscription.asCancellable())
                }
            ),
            value: { currentValueSubject.value }
        )
    }

    public static func combineX(initialValue: Element, willChange: ((Element) -> Void)? = nil) -> ReplayLastSubjectType<Element, ErrorType> {
        .init(currentValueSubject: CurrentValueSubject<Element, ErrorType>(initialValue),
              willChange: willChange)
    }
}
