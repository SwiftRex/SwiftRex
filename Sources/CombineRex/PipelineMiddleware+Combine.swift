#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

extension PipelineMiddleware {
    public static func combine(
        actionTransformer: @escaping ((AnyPublisher<(ActionType, StateType), Never>) -> AnyPublisher<ActionType, Never>) = { _ in
            Empty<ActionType, Never>().eraseToAnyPublisher()
        }
    ) -> PipelineMiddleware {
        return .init(
            actionTransformer: { actionPublisher in
                actionTransformer(actionPublisher.eraseToAnyPublisher()).asPublisherType()
            },
            actionSubject: { .combine() },
            subscriptionCollection: [AnyCancellable].init
        )
    }
}
#endif
