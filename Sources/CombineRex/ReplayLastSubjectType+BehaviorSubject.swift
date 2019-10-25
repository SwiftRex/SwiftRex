#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension ReplayLastSubjectType {
    public init(currentValueSubject: CurrentValueSubject<Element, ErrorType>,
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
                }
            ),
            value: { currentValueSubject.value }
        )
    }

    public static func combine(initialValue: Element, willChange: ((Element) -> Void)? = nil) -> ReplayLastSubjectType<Element, ErrorType> {
        .init(currentValueSubject: CurrentValueSubject<Element, ErrorType>(initialValue),
              willChange: willChange)
    }
}
#endif
