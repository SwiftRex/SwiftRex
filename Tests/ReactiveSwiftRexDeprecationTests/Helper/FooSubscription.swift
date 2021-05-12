import SwiftRex

struct FooSubscription: SubscriptionType {
    let onUnsubscribe: () -> Void
    func unsubscribe() { onUnsubscribe() }
}
