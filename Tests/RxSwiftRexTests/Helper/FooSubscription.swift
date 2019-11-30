import SwiftRex

struct FooSubscription: SwiftRex.SubscriptionType {
    let onUnsubscribe: Next
    func unsubscribe() { onUnsubscribe() }
}
