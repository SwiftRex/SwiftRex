import Foundation

public class PipelineMiddleware<ActionType, StateType>: Middleware {
    public var context: () -> MiddlewareContext<ActionType, StateType>
    private let actionSubject: UnfailableSubject<(StateType, ActionType)>
    private var subscriptionCollection: SubscriptionCollection

    public init(
        actionTransformer: ((PublisherType<(StateType, ActionType), Never>) -> PublisherType<ActionType, Never>)? = nil,
        actionSubject: () -> UnfailableSubject<(StateType, ActionType)>,
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
                    self?.context().actionHandler.dispatch(action)
                }))
                .cancelled(by: &self.subscriptionCollection)
        }
    }

    public func handle(action: ActionType) {
        actionSubject.subscriber.onValue((context().getState(), action))
        context().next(action)
    }
}
