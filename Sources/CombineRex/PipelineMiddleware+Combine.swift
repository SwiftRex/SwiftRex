#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

extension PipelineMiddleware {
    public static func combine(
        actionTransformer: @escaping ((AnyPublisher<(InputActionType, StateType), Never>) -> AnyPublisher<OutputActionType, Never>) = { _ in
            Empty<OutputActionType, Never>().eraseToAnyPublisher()
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
