import Foundation
@testable import SwiftRex
import XCTest

class ViewStoreTests: XCTestCase {
    func testViewStoreDispatchesActionToUpstream() {
        let stateSubject = CurrentValueSubject(currentValue: TestState())
        let shouldCallUpstreamActionHandler = expectation(description: "upstream action handler should have been called")
        let upstreamActionHandler: (AppAction) -> Void = { action in
            XCTAssertEqual(.bar(.delta), action)
            shouldCallUpstreamActionHandler.fulfill()
        }
        let sut = ViewStore<AppAction, TestState>(action: upstreamActionHandler, state: stateSubject.subject.publisher)
        sut.dispatch(.bar(.delta))
        wait(for: [shouldCallUpstreamActionHandler], timeout: 0.1)
    }

    func testViewStoreForwardsStateFromUpstream() {
        let initialState = TestState()
        let shouldNotifyInitialState = expectation(description: "initial state should have been notified")
        let stateSubject = CurrentValueSubject(currentValue: initialState)
        let sut = ViewStore<AppAction, TestState>(action: { _ in }, state: stateSubject.subject.publisher)
        _ = sut.statePublisher.subscribe(.init(onValue: { state in
            XCTAssertEqual(state, initialState)
            shouldNotifyInitialState.fulfill()
        }, onCompleted: nil))
        stateSubject.subject.subscriber.onValue(initialState)
        wait(for: [shouldNotifyInitialState], timeout: 0.1)
    }

    func testViewStoreDispatchesActionToUpstreamStore() {
        let stateSubject = CurrentValueSubject(currentValue: TestState())
        let shouldCallUpstreamActionHandler = expectation(description: "upstream action handler should have been called")

        let middlewareMock = IsoMiddlewareMock<AppAction, TestState>()
        middlewareMock.handleActionNextClosure = { action, _ in
            XCTAssertEqual(.bar(.delta), action)
            shouldCallUpstreamActionHandler.fulfill()
        }

        let originalStore = ReduxStoreBase<AppAction, TestState>(
            subject: stateSubject.subject,
            reducer: createReducerMock().0,
            middleware: middlewareMock
        )

        struct MockViewAction {
            let name: String
        }

        let sut = originalStore.view(
            action: { (viewAction: MockViewAction) in
                guard viewAction.name == "delta" else { return nil }
                return AppAction.bar(.delta)
            },
            state: { $0 }
        )

        sut.dispatch(MockViewAction(name: "delta"))
        sut.dispatch(MockViewAction(name: "ignore"))

        wait(for: [shouldCallUpstreamActionHandler], timeout: 0.1)
    }

    func testViewStoreForwardsStateFromUpstreamStore() {
        let initialState = TestState(value: .init(), name: "this comes from original store")
        let shouldNotifyInitialState = expectation(description: "initial state should have been notified")
        let stateSubject = CurrentValueSubject(currentValue: initialState)

        let originalStore = ReduxStoreBase<AppAction, TestState>(
            subject: stateSubject.subject,
            reducer: createReducerMock().0,
            middleware: IsoMiddlewareMock<AppAction, TestState>()
        )

        struct MockViewState: Equatable {
            let decoratedValue: String
            let decoratedName: String
        }

        let sut = originalStore.view(
            action: { $0 },
            state: { (statePublisher: UnfailablePublisherType<TestState>) -> UnfailablePublisherType<MockViewState> in
                .init { subscriber -> SubscriptionType in
                    statePublisher.subscribe(.init(onValue: { state in
                        subscriber.onValue(
                            MockViewState(
                                decoratedValue: "*** " + state.value.uuidString + " ***",
                                decoratedName: "*** " + state.name + " ***"
                            )
                        )
                    }, onCompleted: nil))
                }
            }
        )

        _ = sut.statePublisher.subscribe(.init(onValue: { state in
            XCTAssertEqual(state, .init(
                decoratedValue: "*** " + initialState.value.uuidString + " ***",
                decoratedName: "*** this comes from original store ***"
            ))
            shouldNotifyInitialState.fulfill()
        }, onCompleted: nil))

        stateSubject.subject.subscriber.onValue(initialState)
        wait(for: [shouldNotifyInitialState], timeout: 0.1)
    }
}
