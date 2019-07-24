import Foundation

public class PipelineMiddleware<StateType>: Middleware {
    public var handlers: MessageHandler!
    private let eventSubject: UnfailableSubject<(StateType, EventProtocol)>
    private let actionSubject: UnfailableSubject<(StateType, ActionProtocol)>
    private var subscriptionCollection: SubscriptionCollection

    public init(
        eventTransformer: ((PublisherType<(StateType, EventProtocol), Never>) -> PublisherType<ActionProtocol, Never>)? = nil,
        actionTransformer: ((PublisherType<(StateType, ActionProtocol), Never>) -> PublisherType<ActionProtocol, Never>)? = nil,
        eventSubject: () -> UnfailableSubject<(StateType, EventProtocol)>,
        actionSubject: () -> UnfailableSubject<(StateType, ActionProtocol)>,
        subscriptionCollection: () -> SubscriptionCollection
        ) {
        self.eventSubject = eventSubject()
        self.actionSubject = actionSubject()
        self.subscriptionCollection = subscriptionCollection()

        if let eventTransformer = eventTransformer {
            eventTransformer(self.eventSubject.publisher)
                .subscribe(.init(onValue: { [weak self] action in
                    self?.handlers?.actionHandler.trigger(action)
                }))
                .cancelled(by: &self.subscriptionCollection)
        }

        if let actionTransformer = actionTransformer {
            actionTransformer(self.actionSubject.publisher)
                .subscribe(.init(onValue: { [weak self] action in
                    self?.handlers?.actionHandler.trigger(action)
                }))
                .cancelled(by: &self.subscriptionCollection)
        }
    }

    public func handle(event: EventProtocol,
                       getState: @escaping () -> StateType,
                       next: @escaping (EventProtocol, @escaping () -> StateType) -> Void) {
        eventSubject.subscriber.onValue((getState(), event))
        next(event, getState)
    }

    public func handle(action: ActionProtocol,
                       getState: @escaping () -> StateType,
                       next: @escaping (ActionProtocol, @escaping () -> StateType) -> Void) {
        actionSubject.subscriber.onValue((getState(), action))
        next(action, getState)
    }
}
