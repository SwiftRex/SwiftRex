#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

extension PipelineMiddleware {
    public static func combine(
        eventTransformer: @escaping ((AnyPublisher<(StateType, EventProtocol), Never>) -> AnyPublisher<ActionProtocol, Never>) = { _ in
            Empty<ActionProtocol, Never>().eraseToAnyPublisher()
        },
        actionTransformer: @escaping ((AnyPublisher<(StateType, ActionProtocol), Never>) -> AnyPublisher<ActionProtocol, Never>) = { _ in
            Empty<ActionProtocol, Never>().eraseToAnyPublisher()
        }
    ) -> PipelineMiddleware {
        return .init(
            eventTransformer: { eventPublisher in
                eventTransformer(eventPublisher.eraseToAnyPublisher()).asPublisherType()
            },
            actionTransformer: { actionPublisher in
                actionTransformer(actionPublisher.eraseToAnyPublisher()).asPublisherType()
            },
            eventSubject: { .combine() },
            actionSubject: { .combine() },
            subscriptionCollection: [AnyCancellable].init
        )
    }
}
#endif
