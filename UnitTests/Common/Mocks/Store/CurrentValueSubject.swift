import SwiftRex

class SubscriptionItem: Subscription {
    let uuid = UUID()
    var onUnsubscribe: (UUID) -> Void

    init(onUnsubscribe: @escaping (UUID) -> Void) {
        self.onUnsubscribe = onUnsubscribe
    }

    func unsubscribe() {
        onUnsubscribe(uuid)
    }
}

// not thread-safe, for use in test only
class CurrentValueSubject {
    var subject: UnfailableReplayLastSubjectType<TestState>!
    var history: [TestState] = []
    var subscribers: [UUID: SubscriberType<TestState, Never>] = [:]
    var currentValue: TestState {
        didSet {
            history.append(oldValue)
        }
    }

    init(currentValue: TestState) {
        self.currentValue = currentValue
        let publisher = PublisherType<TestState, Never> { [weak self] subscriber -> Subscription in
            let subscription = SubscriptionItem(onUnsubscribe: { uuid in
                self?.subscribers.removeValue(forKey: uuid)
            })
            self?.subscribers[subscription.uuid] = subscriber
            return subscription
        }
        let subscriber = SubscriberType<TestState, Never>(
            onValue: { [weak self] state in self?.subscribers.values.forEach { $0.onValue(state) } }
        )
        self.subject = .init(publisher: publisher, subscriber: subscriber, value: {
            [unowned self] in
            self.currentValue
        })
    }
}
