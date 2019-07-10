import Combine
import SwiftRex

struct FooSubscription: SwiftRex.Subscription {
    let onUnsubscribe: () -> Void
    func unsubscribe() { onUnsubscribe() }
}

struct FooCombineSubscription: Combine.Subscription {
    let onUnsubscribe: () -> Void
    var onRequest: ((Subscribers.Demand) -> Void)?

    init(onUnsubscribe: @escaping () -> Void) {
        self.onUnsubscribe = onUnsubscribe
    }

    func request(_ demand: Subscribers.Demand) {
        onRequest?(demand)
    }

    func cancel() {
        onUnsubscribe()
    }

    let combineIdentifier = CombineIdentifier()
}
