import SwiftRex

class FooSubscription: Subscription {
    func unsubscribe() { }
}

final class FooSubscriptionCollection: SubscriptionCollection {
    var appendCalls = 0
    var appendSubscriptionSubscription: Subscription?
    func append(subscription: Subscription) {
        appendSubscriptionSubscription = subscription
        appendCalls += 1
    }
}
