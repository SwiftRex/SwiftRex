import Foundation

public class PipelineMiddleware<InputActionType, OutputActionType, StateType>: Middleware {
    public var context: () -> MiddlewareContext<OutputActionType, StateType>
    private let actionSubject: UnfailableSubject<(InputActionType, StateType)>
    private var subscriptionCollection: SubscriptionCollection

    public init(
        actionTransformer: ((UnfailablePublisherType<(InputActionType, StateType)>) -> UnfailablePublisherType<OutputActionType>)? = nil,
        actionSubject: () -> UnfailableSubject<(InputActionType, StateType)>,
        subscriptionCollection: () -> SubscriptionCollection
    ) {
        self.actionSubject = actionSubject()
        self.subscriptionCollection = subscriptionCollection()
        self.context = {
            fatalError("No context set for middleware PipelineMiddleware, please be sure to configure your middleware prior to usage")
        }

        if let actionTransformer = actionTransformer {
            actionTransformer(self.actionSubject.publisher)
                .subscribe(.init(onValue: { [weak self] action in
                    self?.context().dispatch(action)
                }))
                .cancelled(by: &self.subscriptionCollection)
        }
    }

    /**
     Handles the incoming actions. In the `PipelineMiddleware` this is already implemented for you, by calling the
     action publisher transformation provided during the initialization of this middleware.

     - Parameters:
       - action: the action to be handled
       - next: opportunity to call the next middleware in the chain and, eventually, the reducer pipeline. Call it
               only once, not more or less than once. Call it from the same thread and runloop where the handle function
               is executed, never from a completion handler or dispatch queue block. In case you don't need to compare
               state before and after it's changed from the reducers, please consider to add a `defer` block with `next()`
               on it, at the beginning of `handle` function.
     */
    public func handle(action: InputActionType, next: @escaping Next) {
        actionSubject.subscriber.onValue((action, context().getState()))
        next()
    }
}
