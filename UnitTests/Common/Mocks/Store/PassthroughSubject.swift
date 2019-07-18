import SwiftRex

// not thread-safe, for use in test only
class PassthroughSubject<Element> {
    var subject: UnfailableSubject<Element>!
    var subscribers: [UUID: SubscriberType<Element, Never>] = [:]

    init() {
        let publisher = PublisherType<Element, Never> { [weak self] subscriber -> Subscription in
            let subscription = SubscriptionItem(onUnsubscribe: { uuid in
                self?.subscribers.removeValue(forKey: uuid)
            })
            self?.subscribers[subscription.uuid] = subscriber
            return subscription
        }
        let subscriber = SubscriberType<Element, Never>(
            onValue: { state in
                self.subscribers.values.forEach {
                    $0.onValue(state)
                }
            }
        )
        self.subject = .init(publisher: publisher, subscriber: subscriber)
    }
}
