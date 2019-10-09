#if canImport(Combine)
import Combine
import SwiftRex

struct FooSubscription: SwiftRex.Subscription {
    let onUnsubscribe: Next
    func unsubscribe() { onUnsubscribe() }
}

struct FooCombineSubscription: Combine.Subscription {
    let onUnsubscribe: Next
    var onRequest: ((Subscribers.Demand) -> Void)?

    init(onUnsubscribe: @escaping Next) {
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
#endif
