import SwiftRex

struct FooSubscription: SwiftRex.SubscriptionType {
    let onUnsubscribe: () -> Void
    func unsubscribe() { onUnsubscribe() }
}
