import Foundation
import ReactiveSwift
import SwiftRex

extension PipelineMiddleware {
    public static func reactive(
        actionTransformer: @escaping
            ((SignalProducer<(InputActionType, StateType), Never>) ->
            SignalProducer<OutputActionType, Never>) = { _ in
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
