// swiftlint:disable file_length function_body_length type_body_length

import RxSwift
import RxSwiftRex
@testable import SwiftRex
import XCTest

class EffectMiddlewareTests: XCTestCase {
    func testEffectMiddlewareWithDependenciesButNoSideEffects() {
        var receivedActions = [String]()
        var dispatchedActions = [String]()
        var receivedState = [String]()
        var receivedDependencies = [String]()
        var currentDependency = "d0"
        var currentState = "s0"

        let sut = EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
            receivedActions.append(action)
            receivedState.append(state)
            receivedDependencies.append(context.dependencies())
            return .doNothing
        }.inject({ currentDependency })

        sut.receiveContext(
            getState: { currentState },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "a0", from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual([], receivedActions)
        XCTAssertEqual([], receivedState)
        XCTAssertEqual([], receivedDependencies)
        afterReducer.reducerIsDone()
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0"], receivedActions)
        XCTAssertEqual(["s0"], receivedState)
        XCTAssertEqual(["d0"], receivedDependencies)

        afterReducer = .doNothing()
        currentDependency = "d1"
        currentState = "s1"
        sut.handle(action: "a1", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0", "a1"], receivedActions)
        XCTAssertEqual(["s0", "s1"], receivedState)
        XCTAssertEqual(["d0", "d1"], receivedDependencies)

        afterReducer = .doNothing()
        currentDependency = "d2"
        currentState = "s2"
        sut.handle(action: "a2", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0", "a1", "a2"], receivedActions)
        XCTAssertEqual(["s0", "s1", "s2"], receivedState)
        XCTAssertEqual(["d0", "d1", "d2"], receivedDependencies)
    }

    func testEffectMiddlewareWithoutDependenciesAndNoSideEffects() {
        var receivedActions = [String]()
        var dispatchedActions = [String]()
        var receivedState = [String]()
        var currentState = "s0"

        let sut = EffectMiddleware<String, String, String, Void>.onAction { action, state, _ in
            receivedActions.append(action)
            receivedState.append(state)
            return .doNothing
        }

        sut.receiveContext(
            getState: { currentState },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "a0", from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual([], receivedActions)
        XCTAssertEqual([], receivedState)
        afterReducer.reducerIsDone()
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0"], receivedActions)
        XCTAssertEqual(["s0"], receivedState)

        afterReducer = .doNothing()
        currentState = "s1"
        sut.handle(action: "a1", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0", "a1"], receivedActions)
        XCTAssertEqual(["s0", "s1"], receivedState)

        afterReducer = .doNothing()
        currentState = "s2"
        sut.handle(action: "a2", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0", "a1", "a2"], receivedActions)
        XCTAssertEqual(["s0", "s1", "s2"], receivedState)
    }

    func testEffectMiddlewareWithSideEffects() {
        var dispatchedActions = [String]()
        var currentDependency = "d0"

        let sut = EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
            .just("dispatched \(action) \(state) \(context.dependencies())")
        }.inject({ currentDependency })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "a0", from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["dispatched a0 some_state d0"], dispatchedActions)

        afterReducer = .doNothing()
        currentDependency = "d1"
        sut.handle(action: "a1", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["dispatched a0 some_state d0", "dispatched a1 some_state d1"], dispatchedActions)

        afterReducer = .doNothing()
        currentDependency = "d2"
        sut.handle(action: "a2", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["dispatched a0 some_state d0", "dispatched a1 some_state d1", "dispatched a2 some_state d2"], dispatchedActions)
    }

    func testEffectMiddlewareWithSideEffectsCancelled() {
        let expectedSubscription = expectation(description: "should have been subscribed")
        let expectedCancellation = expectation(description: "should have been cancelled")

        let sut = EffectMiddleware<String, String, String, String>.onAction { action, _, context in
            if action == "cancel" {
                context.toCancel("token")
                return .doNothing
            }

            guard action == "create" else {
                XCTFail("unexpected action")
                return .doNothing
            }

            return Observable<String>.just("output1")
                .delay(.milliseconds(300), scheduler: MainScheduler.instance)
                .do(onNext: { _ in XCTFail("should not have received values") },
                    onError: { _ in XCTFail("should not have received error") },
                    onSubscribed: { expectedSubscription.fulfill() },
                    onDispose: { expectedCancellation.fulfill() })
                .asEffect(cancellationToken: "token")
        }.inject("dep")

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { _, _ in
                XCTFail("should not have received values")
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "create", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()

        afterReducer = .doNothing()
        sut.handle(action: "cancel", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()

        wait(for: [expectedSubscription, expectedCancellation], timeout: 0.5)
    }

    func testEffectMiddlewareWithSomeSideEffectsCancelled() {
        var dispatchedActions = [String]()
        let expectedSubscription1 = expectation(description: "should have been subscribed 1")
        let expectedSubscription2 = expectation(description: "should have been subscribed 2")
        let expectedSubscription3 = expectation(description: "should have been subscribed 3")
        let expectedValue1 = expectation(description: "should have received value 1")
        let expectedCancellation2 = expectation(description: "should have been cancelled")
        let expectedValue3 = expectation(description: "should have received value 3")

        let sut = EffectMiddleware<String, String, String, String>.onAction { action, _, context in
            switch action {
            case "first":
                return Observable<String>.just("output1")
                    .delay(.milliseconds(300), scheduler: MainScheduler.instance)
                    .do(onNext: { _ in expectedValue1.fulfill() },
                        onError: { _ in XCTFail("should not have received error") },
                        onSubscribed: { expectedSubscription1.fulfill() },
                        onDispose: { })
                    .asEffect(cancellationToken: "token1")
            case "second":
                return Observable<String>.just("output2")
                    .delay(.milliseconds(300), scheduler: MainScheduler.instance)
                    .do(onNext: { _ in XCTFail("should not have received values") },
                        onError: { _ in XCTFail("should not have received error") },
                        onSubscribed: { expectedSubscription2.fulfill() },
                        onDispose: { expectedCancellation2.fulfill() })
                    .asEffect(cancellationToken: "token2")
            case "third":
                return Observable<String>.just("output3")
                    .delay(.milliseconds(300), scheduler: MainScheduler.instance)
                    .do(onNext: { _ in expectedValue3.fulfill() },
                        onError: { _ in XCTFail("should not have received error") },
                        onSubscribed: { expectedSubscription3.fulfill() },
                        onDispose: { })
                    .asEffect(cancellationToken: "token3")
            case "cancel second":
                context.toCancel("token2")
                return .doNothing
            default:
                XCTFail("unexpected action")
                return .doNothing
            }
        }.inject("dep")

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "first", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()

        afterReducer = .doNothing()
        sut.handle(action: "second", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()

        afterReducer = .doNothing()
        sut.handle(action: "third", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()

        afterReducer = .doNothing()
        sut.handle(action: "cancel second", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()

        wait(for: [expectedSubscription1, expectedSubscription2, expectedSubscription3, expectedCancellation2, expectedValue1, expectedValue3],
             timeout: 1.0,
             enforceOrder: true
        )
        XCTAssertEqual(["output1", "output3"], dispatchedActions)
    }

    func testEffectMiddlewareWithSideEffectsComposed() {
        var dispatchedActions = [String]()
        var currentDependencyA = "dA0"
        var currentDependencyB = "dB0"

        let sut =
            EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched A \(action) \(state) \(context.dependencies())")
            }.inject({ currentDependencyA })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched B \(action) \(state) \(context.dependencies())")
            }.inject({ currentDependencyB })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "a0", from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["dispatched A a0 some_state dA0", "dispatched B a0 some_state dB0"], dispatchedActions)

        afterReducer = .doNothing()
        currentDependencyA = "dA1"
        currentDependencyB = "dB1"
        sut.handle(action: "a1", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state dA0",
            "dispatched B a0 some_state dB0",
            "dispatched A a1 some_state dA1",
            "dispatched B a1 some_state dB1"
        ], dispatchedActions)

        afterReducer = .doNothing()
        currentDependencyA = "dA2"
        currentDependencyB = "dB2"
        sut.handle(action: "a2", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state dA0",
            "dispatched B a0 some_state dB0",
            "dispatched A a1 some_state dA1",
            "dispatched B a1 some_state dB1",
            "dispatched A a2 some_state dA2",
            "dispatched B a2 some_state dB2"
        ], dispatchedActions)
    }

    func testEffectMiddlewareWithSideEffectsComposedWithDoNothingMiddleware() {
        var dispatchedActions = [String]()
        var currentDependencyA = "dA0"
        var currentDependencyB = "dB0"

        let sut =
            EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched A \(action) \(state) \(context.dependencies())")
            }.inject({ currentDependencyA })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched B \(action) \(state) \(context.dependencies())")
            }.inject({ currentDependencyB })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { _, _, _ in
                .doNothing
            }.inject({ "bla" })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "a0", from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["dispatched A a0 some_state dA0", "dispatched B a0 some_state dB0"], dispatchedActions)

        afterReducer = .doNothing()
        currentDependencyA = "dA1"
        currentDependencyB = "dB1"
        sut.handle(action: "a1", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state dA0",
            "dispatched B a0 some_state dB0",
            "dispatched A a1 some_state dA1",
            "dispatched B a1 some_state dB1"
        ], dispatchedActions)

        afterReducer = .doNothing()
        currentDependencyA = "dA2"
        currentDependencyB = "dB2"
        sut.handle(action: "a2", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state dA0",
            "dispatched B a0 some_state dB0",
            "dispatched A a1 some_state dA1",
            "dispatched B a1 some_state dB1",
            "dispatched A a2 some_state dA2",
            "dispatched B a2 some_state dB2"
        ], dispatchedActions)
    }

    func testEffectMiddlewareWithSideEffectsComposedWithIdentity() {
        var dispatchedActions = [String]()
        var currentDependencyA = "dA0"
        var currentDependencyB = "dB0"

        let sut =
            EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched A \(action) \(state) \(context.dependencies())")
            }.inject({ currentDependencyA })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched B \(action) \(state) \(context.dependencies())")
            }.inject({ currentDependencyB })
            <> EffectMiddleware.identity

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "a0", from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["dispatched A a0 some_state dA0", "dispatched B a0 some_state dB0"], dispatchedActions)

        afterReducer = .doNothing()
        currentDependencyA = "dA1"
        currentDependencyB = "dB1"
        sut.handle(action: "a1", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state dA0",
            "dispatched B a0 some_state dB0",
            "dispatched A a1 some_state dA1",
            "dispatched B a1 some_state dB1"
        ], dispatchedActions)

        afterReducer = .doNothing()
        currentDependencyA = "dA2"
        currentDependencyB = "dB2"
        sut.handle(action: "a2", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state dA0",
            "dispatched B a0 some_state dB0",
            "dispatched A a1 some_state dA1",
            "dispatched B a1 some_state dB1",
            "dispatched A a2 some_state dA2",
            "dispatched B a2 some_state dB2"
        ], dispatchedActions)
    }

    func testEffectMiddlewareWithSideEffectsReaderComposed() {
        var dispatchedActions = [String]()
        var currentDependency = "d0"

        let sut = (
            EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched A \(action) \(state) \(context.dependencies())")
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched B \(action) \(state) \(context.dependencies())")
            }
        ).inject({ currentDependency })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "a0", from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["dispatched A a0 some_state d0", "dispatched B a0 some_state d0"], dispatchedActions)

        afterReducer = .doNothing()
        currentDependency = "d1"
        sut.handle(action: "a1", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1"
        ], dispatchedActions)

        afterReducer = .doNothing()
        currentDependency = "d2"
        sut.handle(action: "a2", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1",
            "dispatched A a2 some_state d2",
            "dispatched B a2 some_state d2"
        ], dispatchedActions)
    }

    func testEffectMiddlewareWithSideEffectsReaderComposedWithDoNothingMiddleware() {
        var dispatchedActions = [String]()
        var currentDependency = "d0"

        let sut = (
            EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched A \(action) \(state) \(context.dependencies())")
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched B \(action) \(state) \(context.dependencies())")
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { _, _, _ in
                .doNothing
            }
        ).inject({ currentDependency })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "a0", from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["dispatched A a0 some_state d0", "dispatched B a0 some_state d0"], dispatchedActions)

        afterReducer = .doNothing()
        currentDependency = "d1"
        sut.handle(action: "a1", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1"
        ], dispatchedActions)

        afterReducer = .doNothing()
        currentDependency = "d2"
        sut.handle(action: "a2", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1",
            "dispatched A a2 some_state d2",
            "dispatched B a2 some_state d2"
        ], dispatchedActions)
    }

    func testEffectMiddlewareWithSideEffectsReaderComposedWithIdentity() {
        var dispatchedActions = [String]()
        var currentDependency = "d0"

        let sut = (
            EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched A \(action) \(state) \(context.dependencies())")
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, state, context in
                .just("dispatched B \(action) \(state) \(context.dependencies())")
            }
            <> .pure(EffectMiddleware.identity)
        ).inject({ currentDependency })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: "a0", from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["dispatched A a0 some_state d0", "dispatched B a0 some_state d0"], dispatchedActions)

        afterReducer = .doNothing()
        currentDependency = "d1"
        sut.handle(action: "a1", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1"
        ], dispatchedActions)

        afterReducer = .doNothing()
        currentDependency = "d2"
        sut.handle(action: "a2", from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1",
            "dispatched A a2 some_state d2",
            "dispatched B a2 some_state d2"
        ], dispatchedActions)
    }

    func testEffectMiddlewareWithSideEffectsLifted() {
        var receivedActions = [String]()
        var dispatchedActions = [String]()
        var receivedState = [String]()
        var receivedDependencies = [String]()
        var currentDependency = 0
        var currentState = 0
        var outputCounter = -1

        let sut = EffectMiddleware<String, Int, String, () -> String>.onAction { action, state, context in
            receivedActions.append(action)
            receivedState.append(state)
            receivedDependencies.append(context.dependencies())
            outputCounter += 1
            return .just(outputCounter)
        }.inject({ "d\(currentDependency)" })
        .lift(
            inputAction: { (int: Int) in "ia\(int)" },
            outputAction: { (int: Int) in "oa\(int)" },
            state: { (int: Int) in "s\(int)" }
        )

        sut.receiveContext(
            getState: { currentState },
            output: .init { action, _ in
                dispatchedActions.append(action)
            }
        )

        var afterReducer: AfterReducer = .doNothing()
        sut.handle(action: 0, from: .here(), afterReducer: &afterReducer)
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual([], receivedActions)
        XCTAssertEqual([], receivedState)
        XCTAssertEqual([], receivedDependencies)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["oa0"], dispatchedActions)
        XCTAssertEqual(["ia0"], receivedActions)
        XCTAssertEqual(["s0"], receivedState)
        XCTAssertEqual(["d0"], receivedDependencies)

        afterReducer = .doNothing()
        currentDependency = 1
        currentState = 1
        sut.handle(action: 1, from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["oa0", "oa1"], dispatchedActions)
        XCTAssertEqual(["ia0", "ia1"], receivedActions)
        XCTAssertEqual(["s0", "s1"], receivedState)
        XCTAssertEqual(["d0", "d1"], receivedDependencies)

        afterReducer = .doNothing()
        currentDependency = 2
        currentState = 2
        sut.handle(action: 2, from: .here(), afterReducer: &afterReducer)
        afterReducer.reducerIsDone()
        XCTAssertEqual(["oa0", "oa1", "oa2"], dispatchedActions)
        XCTAssertEqual(["ia0", "ia1", "ia2"], receivedActions)
        XCTAssertEqual(["s0", "s1", "s2"], receivedState)
        XCTAssertEqual(["d0", "d1", "d2"], receivedDependencies)
    }
}
