import SwiftRex

class FooSubscription: SubscriptionType {
    func unsubscribe() { }
}

final class FooSubscriptionCollection: SubscriptionCollection {
    var storeCalls = 0
    var storeSubscriptionSubscription: SubscriptionType?
    func store(subscription: SubscriptionType) {
        storeSubscriptionSubscription = subscription
        storeCalls += 1
    }
}
