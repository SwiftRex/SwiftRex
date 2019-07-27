import SwiftRex

struct FooSubscription: Subscription {
    let onUnsubscribe: () -> Void
    func unsubscribe() { onUnsubscribe() }
}
