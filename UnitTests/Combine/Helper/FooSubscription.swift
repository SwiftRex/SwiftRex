import Combine
import SwiftRex

struct FooSubscription: SwiftRex.Subscription {
    let onUnsubscribe: () -> Void
    func unsubscribe() { onUnsubscribe() }
}

struct FooCombineSubscription: Combine.Subscription {
    let onUnsubscribe: () -> Void

    func request(_ demand: Subscribers.Demand) { }

    func cancel() {
        onUnsubscribe()
    }

    let combineIdentifier = CombineIdentifier()
}
