import Foundation
import ReactiveSwift
import SwiftRex

extension PipelineMiddleware {
    public static func reactive(
        actionTransformer: @escaping
            ((SignalProducer<(ActionType, StateType), Never>) ->
            SignalProducer<ActionType, Never>) = { _ in
            .empty
        },
        token: Lifetime.Token
    ) -> PipelineMiddleware {
        return .init(
            actionTransformer: { actionPublisher in
                actionTransformer(actionPublisher.producer).asPublisher()
            },
            actionSubject: { .reactive() },
            subscriptionCollection: { Lifetime(token) }
        )
    }
}
