import SwiftRex

struct FooSubscription: Subscription {
    let onUnsubscribe: Next
    func unsubscribe() { onUnsubscribe() }
}
