import Foundation

public class PipelineMiddleware<ActionType, StateType>: Middleware {
    public var context: () -> MiddlewareContext<ActionType, StateType>
    private let actionSubject: UnfailableSubject<(ActionType, StateType)>
    private var subscriptionCollection: SubscriptionCollection

    public init(
        actionTransformer: ((UnfailablePublisherType<(ActionType, StateType)>) -> UnfailablePublisherType<ActionType>)? = nil,
        actionSubject: () -> UnfailableSubject<(ActionType, StateType)>,
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

    public func handle(action: ActionType, next: @escaping Next) {
        actionSubject.subscriber.onValue((action, context().getState()))
        next()
    }
}
