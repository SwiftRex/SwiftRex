#if canImport(Combine)
import Combine
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
struct FooSubscription: SwiftRex.SubscriptionType {
    let onUnsubscribe: () -> Void
    func unsubscribe() { onUnsubscribe() }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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
#endif
