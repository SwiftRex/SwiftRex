import Foundation
import RxSwift
import SwiftRex

extension PipelineMiddleware {
    public static func rx(
        eventTransformer: @escaping ((Observable<(StateType, EventProtocol)>) -> Observable<ActionProtocol>) = { _ in
            .empty()
        },
        actionTransformer: @escaping ((Observable<(StateType, ActionProtocol)>) -> Observable<ActionProtocol>) = { _ in
            .empty()
        }
    ) -> PipelineMiddleware {
        return .init(
            eventTransformer: { eventPublisher in
                eventTransformer(eventPublisher.asObservable())
                    .asPublisher()
                    .assertNoFailure()
            },
            actionTransformer: { actionPublisher in
                actionTransformer(actionPublisher.asObservable())
                    .asPublisher()
                    .assertNoFailure()
            },
            eventSubject: { SubjectType(unfailablePublishSubject: PublishSubject()) },
            actionSubject: { SubjectType(unfailablePublishSubject: PublishSubject()) },
            subscriptionCollection: DisposeBag.init
        )
    }
}
