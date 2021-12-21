@testable import SwiftRex
import XCTest

class LiftMiddlewareTests: XCTestCase {
}

// MARK: - Lifting 3 properties at once
extension LiftMiddlewareTests {
    func testLiftMiddlewareInputActionOutputActionInputState_OutputActionsAreForwardedToGlobalContext() {
        var globalReceived: [DispatchedAction<AppAction>] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action in globalReceived.append(action) }
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> =
            nameMiddleware.lift(
                inputAction: { $0.bar },
                outputAction: { bar in .bar(bar) },
                state: { $0.name }
            )

        nameMiddleware.handleActionFromStateReturnValue = IO { output in
            output.dispatch(.echo, from: .here())
            globalDispatcher.dispatch(.foo, from: .here())
            globalDispatcher.dispatch(.bar(.bravo), from: .here())
            output.dispatch(.delta, from: .here())
        }
        generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState() }).run(globalDispatcher)

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived.map(\.action), expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareInputActionOutputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return IO.pure()
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> =
            nameMiddleware.lift(
                inputAction: { $0.bar },
                outputAction: { bar in .bar(bar) },
                state: { $0.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftMiddlewareInputActionOutputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var middlewareGetState: (() -> String)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in middlewareGetState = getState; return .pure() }

        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> =
            nameMiddleware.lift(
                inputAction: { $0.bar },
                outputAction: { bar in .bar(bar) },
                state: { $0.name }
            )

        generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: .init(), name: "test-unlift-state") })
            .run(.init { _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
    }
}

// MARK: - Lifting 2 properties at once: Input Action, Output Action
extension LiftMiddlewareTests {
    func testLiftMiddlewareInputActionOutputAction_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction.Bar>?
        var globalReceived: [DispatchedAction<AppAction>] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action in globalReceived.append(action) }

        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, TestState>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, TestState>> =
            nameMiddleware.lift(
                inputAction: { $0.bar },
                outputAction: { bar in .bar(bar) }
            )
        nameMiddleware.handleActionFromStateReturnValue = IO { output in localDispatcher = output }
        generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState() })
            .run(globalDispatcher)

        localDispatcher?.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived.map(\.action), expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareInputActionOutputAction_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, TestState>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, TestState>> =
            nameMiddleware.lift(
                inputAction: { $0.bar },
                outputAction: { bar in .bar(bar) }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftMiddlewareInputActionOutputAction_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, TestState>()
        var middlewareGetState: (() -> TestState)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, TestState>> =
            nameMiddleware.lift(
                inputAction: { $0.bar },
                outputAction: { bar in .bar(bar) }
            )

        let uuid = UUID()
        _ = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: uuid, name: "test-unlift-state") })

        XCTAssertEqual(TestState(value: uuid, name: "test-unlift-state"), middlewareGetState?())
    }
}

// MARK: - Lifting 2 properties at once: Input Action, State
extension LiftMiddlewareTests {
    func testLiftMiddlewareInputActionInputState_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction>?
        var globalReceived: [DispatchedAction<AppAction>] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action in globalReceived.append(action) }

        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, String>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction.Bar, AppAction, String>> =
            nameMiddleware.lift(
                inputAction: { $0.bar },
                state: { $0.name }
            )
        nameMiddleware.handleActionFromStateReturnValue = IO { output in localDispatcher = output }
        generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState() }).run(globalDispatcher)

        localDispatcher?.dispatch(.bar(.echo), from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.bar(.delta), from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived.map(\.action), expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareInputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, String>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction.Bar, AppAction, String>> =
            nameMiddleware.lift(
                inputAction: { $0.bar },
                state: { $0.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftMiddlewareInputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, String>()
        var middlewareGetState: (() -> String)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction.Bar, AppAction, String>> =
            nameMiddleware.lift(
                inputAction: { $0.bar },
                state: { $0.name }
            )

        _ = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: .init(), name: "test-unlift-state") })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
    }
}

// MARK: - Lifting 2 properties at once: Output Action, State
extension LiftMiddlewareTests {
    func testLiftMiddlewareOutputActionInputState_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction.Bar>?
        var globalReceived: [DispatchedAction<AppAction>] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action in globalReceived.append(action) }

        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, String>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction, AppAction.Bar, String>> =
            nameMiddleware.lift(
                outputAction: { bar in .bar(bar) },
                state: { $0.name }
            )
        nameMiddleware.handleActionFromStateReturnValue = IO { output in localDispatcher = output }
        generalMiddleware.handle(action: .foo, from: .here(), state: { TestState() }).run(globalDispatcher)

        localDispatcher?.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived.map(\.action), expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareOutputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, String>()
        var receivedActions = [AppAction]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction, AppAction.Bar, String>> =
            nameMiddleware.lift(
                outputAction: { bar in .bar(bar) },
                state: { $0.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(4, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftMiddlewareOutputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, String>()
        var middlewareGetState: (() -> String)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction, AppAction.Bar, String>> =
            nameMiddleware.lift(
                outputAction: { bar in .bar(bar) },
                state: { $0.name }
            )

        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { TestState(value: .init(), name: "test-unlift-state") })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
    }
}

// MARK: - Lifting a single property: Input Action
extension LiftMiddlewareTests {
    func testLiftMiddlewareInputAction_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction>?
        var globalReceived: [DispatchedAction<AppAction>] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action in globalReceived.append(action) }

        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, TestState>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction.Bar, AppAction, TestState>> =
            nameMiddleware.lift(
                inputAction: { $0.bar }
            )
        nameMiddleware.handleActionFromStateReturnValue = IO { output in localDispatcher = output }
        generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState() }).run(globalDispatcher)

        localDispatcher?.dispatch(.bar(.echo), from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.bar(.delta), from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived.map(\.action), expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareInputAction_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, TestState>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction.Bar, AppAction, TestState>> =
            nameMiddleware.lift(
                inputAction: { $0.bar }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftMiddlewareInputAction_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, TestState>()
        var middlewareGetState: (() -> TestState)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction.Bar, AppAction, TestState>> =
            nameMiddleware.lift(
                inputAction: { $0.bar }
            )

        let uuid = UUID()
        _ = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: uuid, name: "test-unlift-state") })

        XCTAssertEqual(TestState(value: uuid, name: "test-unlift-state"), middlewareGetState?())
    }
}

// MARK: - Lifting a single property: Output Action
extension LiftMiddlewareTests {
    func testLiftMiddlewareOutputAction_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction.Bar>?
        var globalReceived: [DispatchedAction<AppAction>] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action in globalReceived.append(action) }

        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, TestState>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction, AppAction.Bar, TestState>> =
            nameMiddleware.lift(
                outputAction: { bar in .bar(bar) }
            )
        nameMiddleware.handleActionFromStateReturnValue = IO { output in localDispatcher = output }
        generalMiddleware.handle(action: .foo, from: .here(), state: { TestState() }).run(globalDispatcher)

        localDispatcher?.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived.map(\.action), expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareOutputAction_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, TestState>()
        var receivedActions = [AppAction]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction, AppAction.Bar, TestState>> =
            nameMiddleware.lift(
                outputAction: { bar in .bar(bar) }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(4, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftMiddlewareOutputAction_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, TestState>()
        var middlewareGetState: (() -> TestState)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction, AppAction.Bar, TestState>> =
            nameMiddleware.lift(
                outputAction: { bar in .bar(bar) }
            )

        let uuid = UUID()
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { TestState(value: uuid, name: "test-unlift-state") })

        XCTAssertEqual(TestState(value: uuid, name: "test-unlift-state"), middlewareGetState?())
    }
}

// MARK: - Lifting a single property: State
extension LiftMiddlewareTests {
    func testLiftMiddlewareInputState_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction>?
        var globalReceived: [DispatchedAction<AppAction>] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action in globalReceived.append(action) }

        let nameMiddleware = MiddlewareMock<AppAction, AppAction, String>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction, AppAction, String>> =
            nameMiddleware.lift(
                state: { $0.name }
            )
        nameMiddleware.handleActionFromStateReturnValue = IO { output in localDispatcher = output }
        generalMiddleware.handle(action: .foo, from: .here(), state: { TestState() }).run(globalDispatcher)

        localDispatcher?.dispatch(.bar(.echo), from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.bar(.delta), from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived.map(\.action), expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction, String>()
        var receivedActions = [AppAction]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction, AppAction, String>> =
            nameMiddleware.lift(
                state: { $0.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(4, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftMiddlewareInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction, String>()
        var middlewareGetState: (() -> String)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, MiddlewareMock<AppAction, AppAction, String>> =
            nameMiddleware.lift(
                state: { $0.name }
            )

        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { TestState(value: .init(), name: "test-unlift-state") })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
    }
}
