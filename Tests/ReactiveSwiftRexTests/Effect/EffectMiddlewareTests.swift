// swiftlint:disable file_length function_body_length type_body_length

import ReactiveSwift
@testable import ReactiveSwiftRex
@testable import SwiftRex
import XCTest

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
                SignalProducer<DispatchedAction<String>, Never>({ DispatchedAction("output1") })
                    .delay(0.3, on: QueueScheduler.main)
                    .on(started: { expectedSubscription.fulfill() },
                        interrupted: { expectedCancellation.fulfill() },
                        value: { _ in XCTFail("should not have received values") })
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
                    SignalProducer<DispatchedAction<String>, Never>({ DispatchedAction("output1") })
                        .delay(0.3, on: QueueScheduler.main)
                        .on(started: { expectedSubscription1.fulfill() },
                            interrupted: { XCTFail("should not have received cancellation") },
                            value: { _ in expectedValue1.fulfill() })
                }
            case "second":
                return Effect(token: "token2") { _ in
                    SignalProducer<DispatchedAction<String>, Never>({ DispatchedAction("output2") })
                        .delay(0.3, on: QueueScheduler.main)
                        .on(started: { expectedSubscription2.fulfill() },
                            interrupted: { expectedCancellation2.fulfill() },
                            value: { _ in XCTFail("should not have received values") })
                }
            case "third":
                return Effect(token: "token3") { _ in
                    SignalProducer<DispatchedAction<String>, Never>({ DispatchedAction("output3") })
                        .delay(0.3, on: QueueScheduler.main)
                        .on(started: { expectedSubscription3.fulfill() },
                            interrupted: { XCTFail("should not have received cancellation") },
                            value: { _ in expectedValue3.fulfill() })
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // ReactiveSwift needs extra runloops to call onDispose / onComplete
            // All of them, the 2 completed and the 1 cancelled should have been removed from the Dictionary
            XCTAssertEqual(sut.cancellables.count, 0)
            waitOneRunLoop.fulfill()
        }
        wait(for: [waitOneRunLoop], timeout: 0.5)
    }

    func testEffectMiddlewareWithNonCompletingPublisherEffectCancelledViaToCancel() {
        var dispatchedActions = [String]()
        let token = "token1"
        let expectedSubscription = expectation(description: "should have been subscribed")
        let expectedCancellation = expectation(description: "should have been cancelled")
        let (signal, subject) = Signal<String, Never>.pipe()

        let sut = EffectMiddleware<String, String, String, Void>.onAction { action, _, _ in
            switch action {
            case "start":
                return Effect(token: token) { _ in
                    signal
                        .map { DispatchedAction($0) }
                        .producer
                        .on(
                            started: { expectedSubscription.fulfill() },
                            interrupted: { expectedCancellation.fulfill() }
                        )
                }
            case "stop":
                return .toCancel(token)
            default:
                XCTFail("Invalid action")
                return .doNothing
            }
        }

        // Nobody cares about this subject yet, this is gonna be ignored
        subject.send(value: "Foo1")
        subject.send(value: "Foo2")

        // Start the effect
        var io = sut.handle(action: "start", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 1)

        subject.send(value: "some value 1")
        subject.send(value: "some value 2")
        subject.send(value: "some value 3")

        io = sut.handle(action: "stop", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })

        subject.send(value: "some value 4")

        wait(for: [expectedSubscription, expectedCancellation],
             timeout: 1.0,
             enforceOrder: true
        )

        subject.send(value: "some value 5")

        XCTAssertEqual(["some value 1", "some value 2", "some value 3"], dispatchedActions)

        XCTAssertEqual(sut.cancellables.count, 0)
    }

    func testEffectMiddlewareWithNonCompletingPublisherEffectCancelledViaEffectCompositionThatHasToCancel() {
        var dispatchedActions = [String]()
        let token = "token1"
        let expectedSubscription = expectation(description: "should have been subscribed")
        let expectedCancellation = expectation(description: "should have been cancelled")
        let (signal, subject) = Signal<String, Never>.pipe()

        let sut = EffectMiddleware<String, String, String, Void>.onAction { action, _, _ in
            switch action {
            case "start":
                return Effect(token: token) { _ in
                    signal
                        .map { DispatchedAction($0) }
                        .producer
                        .on(
                            started: { expectedSubscription.fulfill() },
                            interrupted: { expectedCancellation.fulfill() }
                        )
                }
            case "stop":
                return Effect { context in
                    SignalProducer.merge(
                        context.toCancel(token).producer,
                        SignalProducer(value: .init("ignoring"))
                    )
                }
            case "ignoring":
                return .doNothing
            default:
                XCTFail("Invalid action")
                return .doNothing
            }
        }

        // Nobody cares about this subject yet, this is gonna be ignored
        subject.send(value: "Foo1")
        subject.send(value: "Foo2")

        // Start the effect
        var io = sut.handle(action: "start", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 1)

        subject.send(value: "some value 1")
        subject.send(value: "some value 2")
        subject.send(value: "some value 3")

        io = sut.handle(action: "stop", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })

        subject.send(value: "some value 4")

        wait(for: [expectedSubscription, expectedCancellation],
             timeout: 1.0,
             enforceOrder: true
        )

        subject.send(value: "some value 5")

        XCTAssertEqual(["some value 1", "some value 2", "some value 3", "ignoring"], dispatchedActions)

        XCTAssertEqual(sut.cancellables.count, 0)
    }

    func testEffectMiddlewareWithNonCompletingPublisherEffectCancelledViaSameTokenUsage() {
        var dispatchedActions = [String]()
        let token = "token1"
        let expectedSubscription1 = expectation(description: "should have been subscribed to publisher 1")
        let expectedCancellation1 = expectation(description: "should have been cancelled publisher 1")
        let expectedSubscription2 = expectation(description: "should have been subscribed to publisher 2")
        let (input1, subject1) = Signal<String, Never>.pipe()
        let (input2, subject2) = Signal<String, Never>.pipe()
        let signal1 = input1.producer
        let signal2 = input2.producer
        var middlewareAlive = true

        let sut = EffectMiddleware<String, String, String, Void>.onAction { action, _, _ in
            switch action {
            case "start":
                return Effect(token: token) { _ in
                    // First Publisher
                    signal1
                        .map { DispatchedAction($0) }
                        .on(
                            started: { expectedSubscription1.fulfill() },
                            interrupted: { expectedCancellation1.fulfill() }
                        )
                }
            case "replace":
                // Replaces First Publisher for the Second Publisher, using the same token
                // First is cancelled, Second starts from there
                return Effect(token: token) { _ in
                    signal2
                        .map { DispatchedAction($0) }
                        .on(
                            started: { expectedSubscription2.fulfill() },
                            interrupted: {
                                if middlewareAlive {
                                    XCTFail("Second publisher should not have been cancelled")
                                }
                            }
                        )
                }
            default:
                XCTFail("Invalid action")
                return .doNothing
            }
        }

        // Nobody cares about this subject yet, this is gonna be ignored
        subject1.send(value: "Foo1.1")
        subject1.send(value: "Foo1.2")
        subject2.send(value: "Foo2.1")
        subject2.send(value: "Foo2.2")

        // Start the effect
        var io = sut.handle(action: "start", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 1)

        subject1.send(value: "some value 1")
        subject1.send(value: "some value 2")
        subject1.send(value: "some value 3")
        subject2.send(value: "Foo2.3")
        subject2.send(value: "Foo2.4")
        subject2.send(value: "Foo2.5")

        io = sut.handle(action: "replace", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })

        subject1.send(value: "Foo1.3")
        subject1.send(value: "Foo1.4")

        wait(for: [expectedSubscription1, expectedSubscription2, expectedCancellation1],
             timeout: 1.0,
             enforceOrder: true
        )

        subject1.send(value: "Foo1.5")
        subject1.send(value: "Foo1.6")
        subject2.send(value: "some value 4")
        subject2.send(value: "some value 5")

        XCTAssertEqual(["some value 1", "some value 2", "some value 3", "some value 4", "some value 5"], dispatchedActions)

        XCTAssertEqual(sut.cancellables.count, 1)

        let waitOneRunLoop = expectation(description: "wait next RunLoop")

        DispatchQueue.main.async {
            // Even after next run loop, the second subject effect continues to be alive and kicking
            // (ensure that cancellation of first effect doesn't mistakenly remove the second effect from the dictionary)
            XCTAssertEqual(sut.cancellables.count, 1)
            waitOneRunLoop.fulfill()
        }
        wait(for: [waitOneRunLoop], timeout: 0.01)
        middlewareAlive = false
        _ = sut.cancellables // After this, middleware will be deallocated, then cancellables dict, then the second
                             // subscription, causing interrupt in the subject2.
    }

    func testEffectMiddlewareCancelWrongTokenDoesNothing() {
        var dispatchedActions = [String]()
        let token = "token1"
        let expectedSubscription = expectation(description: "should have been subscribed")
        let (signal, subject) = Signal<String, Never>.pipe()
        var middlewareAlive = true

        let sut = EffectMiddleware<String, String, String, Void>.onAction { action, _, _ in
            switch action {
            case "start":
                return Effect(token: token) { _ in
                    signal
                        .map { DispatchedAction($0) }
                        .producer
                        .on(
                            started: { expectedSubscription.fulfill() },
                            interrupted: {
                                if middlewareAlive {
                                    XCTFail("should not cancel anything")
                                }
                            }
                        )
                }
            case "stop":
                return .toCancel("wrong token")
            default:
                XCTFail("Invalid action")
                return .doNothing
            }
        }

        // Nobody cares about this subject yet, this is gonna be ignored
        subject.send(value: "Foo1")
        subject.send(value: "Foo2")

        // Start the effect
        var io = sut.handle(action: "start", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })
        XCTAssertEqual(sut.cancellables.count, 1)

        subject.send(value: "some value 1")
        subject.send(value: "some value 2")
        subject.send(value: "some value 3")

        io = sut.handle(action: "stop", from: .here(), state: { "some_state" })
        io.run(.init { dispatchedAction in
            dispatchedActions.append(dispatchedAction.action)
        })

        subject.send(value: "some value 4")

        wait(for: [expectedSubscription],
             timeout: 1.0,
             enforceOrder: true
        )

        subject.send(value: "some value 5")

        XCTAssertEqual(["some value 1", "some value 2", "some value 3", "some value 4", "some value 5"], dispatchedActions)

        XCTAssertEqual(sut.cancellables.count, 1)
        middlewareAlive = false
        _ = sut.cancellables // After this, middleware will be deallocated, then cancellables dict, then the second
                             // subscription, causing interrupt in the subject2.
    }

    func testEffectMiddlewareWithSideEffectsComposed() {
        var dispatchedActions = [String]()
        var currentDependencyA = "dA0"
        var currentDependencyB = "dB0"

        let sut =
            EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    SignalProducer(value: .init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }.inject({ currentDependencyA })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    SignalProducer(value: .init("dispatched B \(action) \(state()) \(context.dependencies())"))
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
                    SignalProducer(value: .init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }.inject({ currentDependencyA })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    SignalProducer(value: .init("dispatched B \(action) \(state()) \(context.dependencies())"))
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
                    SignalProducer(value: .init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }.inject({ currentDependencyA })
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    SignalProducer(value: .init("dispatched B \(action) \(state()) \(context.dependencies())"))
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
                    SignalProducer(value: .init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    SignalProducer(value: .init("dispatched B \(action) \(state()) \(context.dependencies())"))
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
    }

    func testEffectMiddlewareWithSideEffectsReaderComposedWithDoNothingMiddleware() {
        var dispatchedActions = [String]()
        var currentDependency = "d0"

        let sut = (
            EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    SignalProducer(value: .init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    SignalProducer(value: .init("dispatched B \(action) \(state()) \(context.dependencies())"))
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
                    SignalProducer(value: .init("dispatched A \(action) \(state()) \(context.dependencies())"))
                }
            }
            <> EffectMiddleware<String, String, String, () -> String>.onAction { action, _, state in
                Effect { context in
                    SignalProducer(value: .init("dispatched B \(action) \(state()) \(context.dependencies())"))
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
