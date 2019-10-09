import SwiftRex

struct FooSubscription: SwiftRex.Subscription {
    let onUnsubscribe: Next
    func unsubscribe() { onUnsubscribe() }
}
