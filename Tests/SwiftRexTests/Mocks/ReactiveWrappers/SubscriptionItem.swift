import Foundation
import SwiftRex

class SubscriptionItem: SubscriptionType {
    let uuid = UUID()
    var onUnsubscribe: (UUID) -> Void

    init(onUnsubscribe: @escaping (UUID) -> Void) {
        self.onUnsubscribe = onUnsubscribe
    }

    func unsubscribe() {
        onUnsubscribe(uuid)
    }
}
