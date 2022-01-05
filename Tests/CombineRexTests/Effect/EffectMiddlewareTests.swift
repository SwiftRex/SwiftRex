// swiftlint:disable file_length function_body_length type_body_length

#if canImport(Combine)
import Combine
@testable import CombineRex
@testable import SwiftRex
import XCTest

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class EffectMiddlewareTests: XCTestCase {
    func testEffectMiddlewareWithDependenciesButNoSideEffects() {
        var receivedActions = [String]()
        var dispatchedActions = [String]()
        var receivedState = [String]()
        var currentDependency = "d0"
        var currentState = "s0"

        let sut = EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
            receivedActions.append(action)
            receivedState.append(state())
            return .doNothing
        }.inject({ currentDependency })

        sut.receiveContext(
            getState: { currentState },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "a0", from: .here(), state: { currentState })
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual([], receivedActions)
        XCTAssertEqual([], receivedState)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0"], receivedActions)
        XCTAssertEqual(["s0"], receivedState)

        currentDependency = "d1"
        currentState = "s1"
        io = sut.handle(action: "a1", from: .here(), state: { currentState })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0", "a1"], receivedActions)
        XCTAssertEqual(["s0", "s1"], receivedState)

        currentDependency = "d2"
        currentState = "s2"
        io = sut.handle(action: "a2", from: .here(), state: { currentState })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0", "a1", "a2"], receivedActions)
        XCTAssertEqual(["s0", "s1", "s2"], receivedState)
    }

    func testEffectMiddlewareWithoutDependenciesAndNoSideEffects() {
        var receivedActions = [String]()
        var dispatchedActions = [String]()
        var receivedState = [String]()
        var currentState = "s0"

        let sut = EffectMiddleware<String, String, String, Void>.onAction { action, _, state in
            receivedActions.append(action)
            receivedState.append(state())
            return .doNothing
        }

        sut.receiveContext(
            getState: { currentState },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "a0", from: .here(), state: { currentState })
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual([], receivedActions)
        XCTAssertEqual([], receivedState)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0"], receivedActions)
        XCTAssertEqual(["s0"], receivedState)

        currentState = "s1"
        io = sut.handle(action: "a1", from: .here(), state: { currentState })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0", "a1"], receivedActions)
        XCTAssertEqual(["s0", "s1"], receivedState)

        currentState = "s2"
        io = sut.handle(action: "a2", from: .here(), state: { currentState })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual(["a0", "a1", "a2"], receivedActions)
        XCTAssertEqual(["s0", "s1", "s2"], receivedState)
    }

    func testEffectMiddlewareWithSideEffects() {
        var dispatchedActions = [String]()
        var currentDependency = "d0"

        let sut = EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
            .just("dispatched \(action) \(state())")
        }.inject({ currentDependency })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "a0", from: .here(), state: { "some_state" })
        XCTAssertEqual([], dispatchedActions)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["dispatched a0 some_state"], dispatchedActions)

        currentDependency = "d1"
        io = sut.handle(action: "a1", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["dispatched a0 some_state", "dispatched a1 some_state"], dispatchedActions)

        currentDependency = "d2"
        io = sut.handle(action: "a2", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["dispatched a0 some_state", "dispatched a1 some_state", "dispatched a2 some_state"], dispatchedActions)
    }

    func testEffectMiddlewareWithSideEffectsCancelled() {
        let expectedSubscription = expectation(description: "should have been subscribed")
        let expectedCancellation = expectation(description: "should have been cancelled")

        let sut = EffectMiddleware<String, String, String, String>.onAction { action, _, _ in
            if action == "cancel" {
                return Effect<String, String> { context in
                    context.toCancel("token")
                }
            }

            guard action == "create" else {
                XCTFail("unexpected action")
                return .doNothing
            }

            return Effect(token: "token") { _ in
                Deferred {
                    Future { completion in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            completion(.success(.init("output1")))
                        }
                    }
                }
                .handleEvents(
                    receiveSubscription: { _ in expectedSubscription.fulfill() },
                    receiveOutput: { _ in XCTFail("should not have received values") },
                    receiveCancel: { expectedCancellation.fulfill() }
                )
            }
        }.inject("dep")

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { _ in
                XCTFail("should not have received values")
            }
        )

        var io = sut.handle(action: "create", from: .here(), state: { "some_state" })
        io.run(.init { _ in
            XCTFail("should not have received values")
        })
        XCTAssertEqual(sut.cancellables.count, 1)

        io = sut.handle(action: "cancel", from: .here(), state: { "some_state" })
        io.run(.init { _ in
            XCTFail("should not have received values")
        })

        wait(for: [expectedSubscription, expectedCancellation], timeout: 0.5)
        XCTAssertEqual(sut.cancellables.count, 0)
    }

    func testEffectMiddlewareWithSomeSideEffectsCancelled() {
        var dispatchedActions = [String]()
        let expectedSubscription1 = expectation(description: "should have been subscribed 1")
        let expectedSubscription2 = expectation(description: "should have been subscribed 2")
        let expectedSubscription3 = expectation(description: "should have been subscribed 3")
        let expectedValue1 = expectation(description: "should have received value 1")
        let expectedCancellation2 = expectation(description: "should have been cancelled")
        let expectedValue3 = expectation(description: "should have received value 3")

        let sut = EffectMiddleware<String, String, String, String>.onAction { action, _, _ in
            switch action {
            case "first":
                return Effect(token: "token1") { _ in
                    Deferred {
                        Future { completion in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                completion(.success(.init("output1")))
                            }
                        }
                    }
                    .handleEvents(receiveSubscription: { _ in expectedSubscription1.fulfill() },
                                  receiveOutput: { _ in expectedValue1.fulfill() },
                                  receiveCancel: { XCTFail("should not have received cancellation") })
                }
            case "second":
                return Effect(token: "token2") { _ in
                    Deferred {
                        Future { completion in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                completion(.success(.init("output2")))
                            }
                        }
                    }
                    .handleEvents(receiveSubscription: { _ in expectedSubscription2.fulfill() },
                                  receiveOutput: { _ in XCTFail("should not have received values") },
                                  receiveCancel: { expectedCancellation2.fulfill() })
                }
            case "third":
                return Effect(token: "token3") { _ in
                    Deferred {
                        Future { completion in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                completion(.success(.init("output3")))
                            }
                        }
                    }
                    .handleEvents(receiveSubscription: { _ in expectedSubscription3.fulfill() },
                                  receiveOutput: { _ in expectedValue3.fulfill() },
                                  receiveCancel: { XCTFail("should not have received cancellation") })
                }
            case "cancel second":
                return .toCancel("token2")
            default:
                XCTFail("unexpected action")
                return .doNothing
            }
        }.inject("dep")

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "first", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 1)

        io = sut.handle(action: "second", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 2)

        io = sut.handle(action: "third", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 3)

        io = sut.handle(action: "cancel second", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })

        wait(for: [expectedSubscription1, expectedSubscription2, expectedSubscription3, expectedCancellation2, expectedValue1, expectedValue3],
             timeout: 1.0,
             enforceOrder: true
        )
        XCTAssertEqual(["output1", "output3"], dispatchedActions)

        let waitOneRunLoop = expectation(description: "wait next RunLoop")

        DispatchQueue.main.async {
            // All of them, the 2 completed and the 1 cancelled should have been removed from the Dictionary
            XCTAssertEqual(sut.cancellables.count, 0)
            waitOneRunLoop.fulfill()
        }
        wait(for: [waitOneRunLoop], timeout: 0.01)
    }

    func testEffectMiddlewareWithNonCompletingPublisherEffectCancelledViaToCancel() {
        var dispatchedActions = [String]()
        let token = "token1"
        let expectedSubscription = expectation(description: "should have been subscribed")
        let expectedCancellation = expectation(description: "should have been cancelled")
        let subject = PassthroughSubject<String, Never>()

        let sut = EffectMiddleware<String, String, String, Void>.onAction { action, _, _ in
            switch action {
            case "start":
                return Effect(token: token) { _ in
                    subject
                        .map { DispatchedAction($0) }
                        .handleEvents(
                            receiveSubscription: { _ in expectedSubscription.fulfill() },
                            receiveCancel: { expectedCancellation.fulfill() }
                        )
                }
            case "stop":
                return .toCancel(token)
            default:
                XCTFail("Invalid action")
                return .doNothing
            }
        }

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        // Nobody cares about this subject yet, this is gonna be ignored
        subject.send("Foo1")
        subject.send("Foo2")

        // Start the effect
        var io = sut.handle(action: "start", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 1)

        subject.send("some value 1")
        subject.send("some value 2")
        subject.send("some value 3")

        io = sut.handle(action: "stop", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })

        subject.send("some value 4")

        wait(for: [expectedSubscription, expectedCancellation],
             timeout: 1.0,
             enforceOrder: true
        )

        subject.send("some value 5")

        XCTAssertEqual(["some value 1", "some value 2", "some value 3"], dispatchedActions)

        let waitOneRunLoop = expectation(description: "wait next RunLoop")

        DispatchQueue.main.async {
            // All of them, the 2 completed and the 1 cancelled should have been removed from the Dictionary
            XCTAssertEqual(sut.cancellables.count, 0)
            waitOneRunLoop.fulfill()
        }
        wait(for: [waitOneRunLoop], timeout: 0.01)
    }

    func testEffectMiddlewareWithNonCompletingPublisherEffectCancelledViaEffectCompositionThatHasToCancel() {
        var dispatchedActions = [String]()
        let token = "token1"
        let expectedSubscription = expectation(description: "should have been subscribed")
        let expectedCancellation = expectation(description: "should have been cancelled")
        let subject = PassthroughSubject<String, Never>()

        let sut = EffectMiddleware<String, String, String, Void>.onAction { action, _, _ in
            switch action {
            case "start":
                return Effect(token: token) { _ in
                    subject
                        .map { DispatchedAction($0) }
                        .handleEvents(
                            receiveSubscription: { _ in expectedSubscription.fulfill() },
                            receiveCancel: { expectedCancellation.fulfill() }
                        )
                }
            case "stop":
                return Effect { context in
                    Publishers.Merge(
                        context.toCancel(token),
                        Just(.init("ignoring"))
                    )
                }
            case "ignoring":
                return .doNothing
            default:
                XCTFail("Invalid action")
                return .doNothing
            }
        }

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        // Nobody cares about this subject yet, this is gonna be ignored
        subject.send("Foo1")
        subject.send("Foo2")

        // Start the effect
        var io = sut.handle(action: "start", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 1)

        subject.send("some value 1")
        subject.send("some value 2")
        subject.send("some value 3")

        io = sut.handle(action: "stop", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })

        subject.send("some value 4")

        wait(for: [expectedSubscription, expectedCancellation],
             timeout: 1.0,
             enforceOrder: true
        )

        subject.send("some value 5")

        XCTAssertEqual(["some value 1", "some value 2", "some value 3", "ignoring"], dispatchedActions)

        let waitOneRunLoop = expectation(description: "wait next RunLoop")

        DispatchQueue.main.async {
            // All of them, the 2 completed and the 1 cancelled should have been removed from the Dictionary
            XCTAssertEqual(sut.cancellables.count, 0)
            waitOneRunLoop.fulfill()
        }
        wait(for: [waitOneRunLoop], timeout: 0.01)
    }

    func testEffectMiddlewareWithSideEffectsComposed() {
        var dispatchedActions = [String]()
        var currentDependencyA = "dA0"
        var currentDependencyB = "dB0"

        let sut =
            EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }.inject({ currentDependencyA })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched B \(action) \(state()) \(context.dependencies())"))
                }
            }.inject({ currentDependencyB })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "a0", from: .here(), state: { "some_state" })
        XCTAssertEqual([], dispatchedActions)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["dispatched A a0 some_state dA0", "dispatched B a0 some_state dB0"], dispatchedActions)

        currentDependencyA = "dA1"
        currentDependencyB = "dB1"
        io = sut.handle(action: "a1", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([
            "dispatched A a0 some_state dA0",
            "dispatched B a0 some_state dB0",
            "dispatched A a1 some_state dA1",
            "dispatched B a1 some_state dB1"
        ], dispatchedActions)

        currentDependencyA = "dA2"
        currentDependencyB = "dB2"
        io = sut.handle(action: "a2", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
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
            EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }.inject({ currentDependencyA })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched B \(action) \(state()) \(context.dependencies())"))
                }
            }.inject({ currentDependencyB })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { _, _, _ in
                .doNothing
            }.inject({ "bla" })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "a0", from: .here(), state: { "some_state" })
        XCTAssertEqual([], dispatchedActions)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["dispatched A a0 some_state dA0", "dispatched B a0 some_state dB0"], dispatchedActions)

        currentDependencyA = "dA1"
        currentDependencyB = "dB1"
        io = sut.handle(action: "a1", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([
            "dispatched A a0 some_state dA0",
            "dispatched B a0 some_state dB0",
            "dispatched A a1 some_state dA1",
            "dispatched B a1 some_state dB1"
        ], dispatchedActions)

        currentDependencyA = "dA2"
        currentDependencyB = "dB2"
        io = sut.handle(action: "a2", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
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
            EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }.inject({ currentDependencyA })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched B \(action) \(state()) \(context.dependencies())"))
                }
            }.inject({ currentDependencyB })
            <> EffectMiddleware.identity

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "a0", from: .here(), state: { "some_state" })
        XCTAssertEqual([], dispatchedActions)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["dispatched A a0 some_state dA0", "dispatched B a0 some_state dB0"], dispatchedActions)

        currentDependencyA = "dA1"
        currentDependencyB = "dB1"
        io = sut.handle(action: "a1", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })

        XCTAssertEqual([
            "dispatched A a0 some_state dA0",
            "dispatched B a0 some_state dB0",
            "dispatched A a1 some_state dA1",
            "dispatched B a1 some_state dB1"
        ], dispatchedActions)

        currentDependencyA = "dA2"
        currentDependencyB = "dB2"
        io = sut.handle(action: "a2", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
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
            EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched B \(action) \(state()) \(context.dependencies())"))
                }
            }
        ).inject({ currentDependency })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "a0", from: .here(), state: { "some_state" })
        XCTAssertEqual([], dispatchedActions)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 0)
        XCTAssertEqual(["dispatched A a0 some_state d0", "dispatched B a0 some_state d0"], dispatchedActions)

        currentDependency = "d1"
        io = sut.handle(action: "a1", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1"
        ], dispatchedActions)

        currentDependency = "d2"
        io = sut.handle(action: "a2", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1",
            "dispatched A a2 some_state d2",
            "dispatched B a2 some_state d2"
        ], dispatchedActions)
        XCTAssertEqual(sut.cancellables.count, 0)
    }

    func testEffectMiddlewareWithSideEffectsReaderComposedWithDoNothingMiddleware() {
        var dispatchedActions = [String]()
        var currentDependency = "d0"

        let sut = (
            EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched B \(action) \(state()) \(context.dependencies())"))
                }
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { _, _, _ in
                .doNothing
            }
        ).inject({ currentDependency })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "a0", from: .here(), state: { "some_state" })
        XCTAssertEqual([], dispatchedActions)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 0)
        XCTAssertEqual(["dispatched A a0 some_state d0", "dispatched B a0 some_state d0"], dispatchedActions)

        currentDependency = "d1"
        io = sut.handle(action: "a1", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 0)
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1"
        ], dispatchedActions)

        currentDependency = "d2"
        io = sut.handle(action: "a2", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 0)
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1",
            "dispatched A a2 some_state d2",
            "dispatched B a2 some_state d2"
        ], dispatchedActions)
        XCTAssertEqual(sut.cancellables.count, 0)
    }

    func testEffectMiddlewareWithSideEffectsReaderComposedWithIdentity() {
        var dispatchedActions = [String]()
        var currentDependency = "d0"

        let sut = (
            EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    Just(.init("dispatched B \(action) \(state()) \(context.dependencies())"))
                }
            }
            <> .pure(EffectMiddleware.identity)
        ).inject({ currentDependency })

        sut.receiveContext(
            getState: { "some_state" },
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: "a0", from: .here(), state: { "some_state" })
        XCTAssertEqual([], dispatchedActions)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["dispatched A a0 some_state d0", "dispatched B a0 some_state d0"], dispatchedActions)

        currentDependency = "d1"
        io = sut.handle(action: "a1", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual([
            "dispatched A a0 some_state d0",
            "dispatched B a0 some_state d0",
            "dispatched A a1 some_state d1",
            "dispatched B a1 some_state d1"
        ], dispatchedActions)

        currentDependency = "d2"
        io = sut.handle(action: "a2", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
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
        var currentDependency = 0
        var currentState = 0
        var outputCounter = -1

        let sut = EffectMiddleware<String, Int, String, () -> String>.onAction { action, _, state in
            receivedActions.append(action)
            receivedState.append(state())
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
            output: .init { dispatchedAction in
                dispatchedActions.append(dispatchedAction.action)
            }
        )

        var io = sut.handle(action: 0, from: .here(), state: { currentState })
        XCTAssertEqual([], dispatchedActions)
        XCTAssertEqual([], receivedActions)
        XCTAssertEqual([], receivedState)
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["oa0"], dispatchedActions)
        XCTAssertEqual(["ia0"], receivedActions)
        XCTAssertEqual(["s0"], receivedState)

        currentDependency = 1
        currentState = 1
        io = sut.handle(action: 1, from: .here(), state: { currentState })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["oa0", "oa1"], dispatchedActions)
        XCTAssertEqual(["ia0", "ia1"], receivedActions)
        XCTAssertEqual(["s0", "s1"], receivedState)

        currentDependency = 2
        currentState = 2
        io = sut.handle(action: 2, from: .here(), state: { currentState })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(["oa0", "oa1", "oa2"], dispatchedActions)
        XCTAssertEqual(["ia0", "ia1", "ia2"], receivedActions)
        XCTAssertEqual(["s0", "s1", "s2"], receivedState)
    }
}
#endif
