import Foundation
import ReactiveSwift
import SwiftRex

extension ReplayLastSubjectType where ErrorType == Never {
    public init<P: MutablePropertyProtocol>(property: P) where P.Value == Element {
        self.init(
            publisher: property.producer.asPublisher(),
            subscriber: SubscriberType(onValue: { property.value = $0 }),
            value: { property.value }
        )
    }

    public static func reactive(initialValue: Element) -> ReplayLastSubjectType {
        let property = MutableProperty<Element>(initialValue)
        return .init(property: property)
    }
}
