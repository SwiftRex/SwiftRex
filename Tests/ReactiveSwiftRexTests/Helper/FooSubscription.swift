import SwiftRex

struct FooSubscription: SubscriptionType {
    let onUnsubscribe: Next
    func unsubscribe() { onUnsubscribe() }
}
