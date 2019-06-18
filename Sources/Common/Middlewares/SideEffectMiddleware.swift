import Foundation

/**
 When the `SideEffectMiddleware` starts a `SideEffectProducer` which throws an error, the middleware will wrap the error in a `ActionProtocol` of type `SideEffectError`, which contains details about the error, the date and time when it happened and the original event that was being handled by the middleware.
 */
public struct SideEffectError: ActionProtocol {
    /// Date and time when the error happened
    public var date: Date

    /// The original event that was being handled by the middleware when the error was thrown
    public let originalEvent: EventProtocol

    /// The error thrown by the `SideEffectProducer` to the `SideEffectMiddleware`
    public let error: Error
}

/**
 Defines a protocol for implementing a middleware that executes `RxSwift` or `ReactiveSwift` side-effects. Instead of implementing the regular `handle(event:getState:next:)` and `handle(action:getState:next:)` methods, this protocol only requires a mapping from `EventProtocol` to `SideEffectProducer`.
 */
// sourcery: AutoMockable
// sourcery: AutoMockableGeneric = StateType
// sourcery: AutoMockableSkip = "handle(event: EventProtocol, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>)"
// sourcery: AutoMockableSkip = "handle(action: ActionProtocol, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>)"
public protocol SideEffectMiddleware: Middleware {
    /// Allows the following middlewares in the chain to have a chance of handling the same events already handled
    var allowEventToPropagate: Bool { get }

    /// A bag that owns the lifetime of each `SideEffectProducer` observation, usually this `SubscriptionOwner` will be a stored property in the `SideEffectMiddleware` instance
    var subscription: Subscription { get set }

    /// Maps the incoming event to the proper `SideEffectProducer`, wrapped in a type-eraser `AnySideEffectProducer`
    func sideEffect(for event: EventProtocol) -> AnySideEffectProducer<StateType>?
}

extension SideEffectMiddleware {
    /**
     Handles the incoming events and may trigger side-effects, may trigger actions, may start an asynchronous operation.
     - Parameters:
       - event: the event to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware in the chain, probably we want to call this method in some point of our method (not necessarily in the end.
     */
    public func handle(event: EventProtocol, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) {
        guard let sideEffect = sideEffect(for: event) else {
            next(event, getState)
            return
        }

        self.subscription = sideEffect
            .execute(getState: getState)
            .subscribe(
                SubscriberType(
                    onValue: { [weak self] action in
                        self?.handlers?.actionHandler.trigger(action)
                    }, onError: { [weak self] error in
                        let action = SideEffectError(date: Date(), originalEvent: event, error: error)
                        self?.handlers?.actionHandler.trigger(action)
                    }
                )
            )

        guard allowEventToPropagate else { return }

        next(event, getState)
    }

    /**
     Handles the incoming actions and may change them or trigger additional ones. Usually this is not the best place to start side-effects or trigger new actions, it should be more as an observation point for tracking, logging and telemetry.
     - Parameters:
       - action: the action to be handled
       - getState: a function that can be used to get the current state at any point in time
       - next: the next `Middleware` in the chain, probably we want to call this method in some point of our method (not necessarily in the end. When this is the last middleware in the pipeline, the next function will call the `Reducer` pipeline.
     */
    public func handle(action: ActionProtocol, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>) {
        next(action, getState)
    }
}
