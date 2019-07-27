import Foundation
import ReactiveSwift
import SwiftRex

extension PipelineMiddleware {
    public static func reactive(
        eventTransformer: @escaping
            ((SignalProducer<(StateType, SwiftRex.EventProtocol), Never>) ->
            SignalProducer<ActionProtocol, Never>) = { _ in
            .empty
        },
        actionTransformer: @escaping
            ((SignalProducer<(StateType, ActionProtocol), Never>) ->
            SignalProducer<ActionProtocol, Never>) = { _ in
            .empty
        },
        token: Lifetime.Token
    ) -> PipelineMiddleware {
        return .init(
            eventTransformer: { eventPublisher in
                eventTransformer(eventPublisher.producer).asPublisher()
            },
            actionTransformer: { actionPublisher in
                actionTransformer(actionPublisher.producer).asPublisher()
            },
            eventSubject: { .reactive() },
            actionSubject: { .reactive() },
            subscriptionCollection: { Lifetime(token) }
        )
    }
}
