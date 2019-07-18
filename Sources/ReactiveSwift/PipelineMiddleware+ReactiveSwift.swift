import Foundation
import ReactiveSwift
import SwiftRex

extension PipelineMiddleware {
    public static func reactive(
        eventTransformer: @escaping ((Signal<(StateType, SwiftRex.EventProtocol), Never>) -> Signal<ActionProtocol, Never>) = { _ in
            .empty
        },
        actionTransformer: @escaping ((Signal<(StateType, ActionProtocol), Never>) -> Signal<ActionProtocol, Never>) = { _ in
            .empty
        }
    ) -> PipelineMiddleware {
        return .init(
            eventTransformer: { eventPublisher in
                eventTransformer(eventPublisher.signal).asPublisher()
            },
            actionTransformer: { actionPublisher in
                actionTransformer(actionPublisher.signal).asPublisher()
            },
            eventSubject: { .reactive() },
            actionSubject: { .reactive() },
            subscriptionCollection: { Lifetime.make().lifetime }
        )
    }
}
