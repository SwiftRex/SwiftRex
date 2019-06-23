import Combine
import Foundation
import SwiftRex

extension SwiftRex.SubjectType {
    public init(passthroughSubject: PassthroughSubject<Element, ErrorType>) {
        self.init(
            publisher: passthroughSubject.asPublisherType(),
            subscriber: SubscriberType(
                onValue: { passthroughSubject.send($0) },
                onCompleted: { error in
                    passthroughSubject.send(completion: error.map(Subscribers.Completion<ErrorType>.failure) ?? .finished)
                }
            )
        )
    }
}

extension SwiftRex.SubjectType {
    public static func combine() -> SwiftRex.SubjectType<Element, ErrorType> {
        let passthroughSubject = PassthroughSubject<Element, ErrorType>()
        return .init(passthroughSubject: passthroughSubject)
    }
}
