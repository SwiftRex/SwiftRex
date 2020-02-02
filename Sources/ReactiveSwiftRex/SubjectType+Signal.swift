import Foundation
import ReactiveSwift
import SwiftRex

extension SubjectType {
    public init(input: Signal<Element, ErrorType>.Observer, output: Signal<Element, ErrorType>) {
        self.init(
            publisher: output.asPublisherType(),
            subscriber: input.asSubscriberType()
        )
    }

    public static func reactive() -> SubjectType {
        let signal = Signal<Element, ErrorType>.pipe()
        return .init(input: signal.input, output: signal.output)
    }
}
