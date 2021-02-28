import CombineX
import CXFoundation
import SwiftRex

struct FooSubscription: SwiftRex.SubscriptionType {
    let onUnsubscribe: () -> Void
    func unsubscribe() { onUnsubscribe() }
}

struct FooCombineSubscription: CombineX.Subscription {
    let onUnsubscribe: () -> Void
    var onRequest: ((CombineX.Subscribers.Demand) -> Void)?

    init(onUnsubscribe: @escaping () -> Void) {
        self.onUnsubscribe = onUnsubscribe
    }

    func request(_ demand: CombineX.Subscribers.Demand) {
        onRequest?(demand)
    }

    func cancel() {
        onUnsubscribe()
    }

    let combineIdentifier = CombineIdentifier()
}
