import SwiftRex

class FooSubscription: Subscription {
    func unsubscribe() { }
}

final class FooSubscriptionCollection: SubscriptionCollection {
    var storeCalls = 0
    var storeSubscriptionSubscription: Subscription?
    func store(subscription: Subscription) {
        storeSubscriptionSubscription = subscription
        storeCalls += 1
    }
}
