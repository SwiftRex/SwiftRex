import SwiftRex

struct FooSubscription: SwiftRex.Subscription {
    let onUnsubscribe: () -> Void
    func unsubscribe() { onUnsubscribe() }
}
