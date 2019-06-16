import SwiftRex

class SideEffectMiddlewareMock: SideEffectMiddleware {
    var allowEventToPropagate: Bool {
        get { return underlyingAllowEventToPropagate }
        set(value) { underlyingAllowEventToPropagate = value }
    }
    var underlyingAllowEventToPropagate: Bool!
    var subscriptionOwner: SubscriptionOwner {
        get { return underlyingSubscriptionOwner }
        set(value) { underlyingSubscriptionOwner = value }
    }
    var underlyingSubscriptionOwner: SubscriptionOwner!
    var actionHandler: ActionHandler?

    // MARK: - sideEffect

    var sideEffectForCallsCount = 0
    var sideEffectForCalled: Bool {
        return sideEffectForCallsCount > 0
    }
    var sideEffectForReceivedEvent: EventProtocol?
    var sideEffectForReturnValue: AnySideEffectProducer<StateType>?!
    var sideEffectForClosure: ((EventProtocol) -> AnySideEffectProducer<StateType>?)?

    func sideEffect(for event: EventProtocol) -> AnySideEffectProducer<StateType>? {
        sideEffectForCallsCount += 1
        sideEffectForReceivedEvent = event
        return sideEffectForClosure.map { $0(event) } ?? sideEffectForReturnValue
    }
}

extension SideEffectMiddlewareMock {
    typealias StateType = TestState
}
