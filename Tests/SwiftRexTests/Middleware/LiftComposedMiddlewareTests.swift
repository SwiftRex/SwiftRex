@testable import SwiftRex
import XCTest

class LiftComposedMiddlewareTests: XCTestCase {
}

// MARK: - Lifting 3 properties at once
extension LiftComposedMiddlewareTests {
    func testLiftMiddlewareInputActionOutputActionInputState_OutputActionsAreForwardedToGlobalContext() {
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }
        let localDispatcher: AnyActionHandler<AppAction.Bar> = .init { dispatchedAction in
            globalDispatcher.dispatch(AppAction.bar(dispatchedAction.action), from: dispatchedAction.dispatcher)
        }

        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )
        nameMiddleware.handleActionFromStateClosure = { _, _, _ in

            return .pure()
        }

        // Now we can dispatch actions through our local dispatcher
        localDispatcher.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionOutputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionOutputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var middlewareGetState: (() -> String)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )

        let io = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: .init(), name: "test-unlift-state") })
        io.run(.init { _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }
}

// MARK: - Lifting 2 properties at once: Input Action, Output Action
extension LiftComposedMiddlewareTests {
    func testLiftMiddlewareInputActionOutputAction_OutputActionsAreForwardedToGlobalContext() {

        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }
        let localDispatcher: AnyActionHandler<AppAction.Bar> = .init { dispatchedAction in
            globalDispatcher.dispatch(.bar(dispatchedAction.action), from: dispatchedAction.dispatcher)
        }

        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, TestState>()
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) }
            )
        nameMiddleware.handleActionFromStateClosure = { _, _, _ in

            return .pure()
        }
        _ = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState() })

        localDispatcher.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionOutputAction_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, TestState>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionOutputAction_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, TestState>()
        var middlewareGetState: (() -> TestState)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) }
            )

        let uuid = UUID()
        let io = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: uuid, name: "test-unlift-state") })
        io.run(.init { _ in })

        XCTAssertEqual(TestState(value: uuid, name: "test-unlift-state"), middlewareGetState?())
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }
}

// MARK: - Lifting 2 properties at once: Input Action, State
extension LiftComposedMiddlewareTests {
    func testLiftMiddlewareInputActionInputState_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, String>()
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                state: { (global: TestState) in global.name }
            )
        nameMiddleware.handleActionFromStateClosure = { _, _, _ in
            localDispatcher = .init { dispatchedAction in
                globalDispatcher.dispatch(dispatchedAction.action, from: dispatchedAction.dispatcher)
            }
            return .pure()
        }
        _ = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState() })

        localDispatcher?.dispatch(.bar(.echo), from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.bar(.delta), from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, String>()
        let composed = nameMiddleware <> IdentityMiddleware()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                state: { (global: TestState) in global.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, String>()
        let composed = nameMiddleware <> IdentityMiddleware()
        var middlewareGetState: (() -> String)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                state: { (global: TestState) in global.name }
            )

        let io = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: .init(), name: "test-unlift-state") })
        io.run(.init { _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }
}

// MARK: - Lifting 2 properties at once: Output Action, State
extension LiftComposedMiddlewareTests {
    func testLiftMiddlewareOutputActionInputState_OutputActionsAreForwardedToGlobalContext() {

        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }
        let localDispatcher: AnyActionHandler<AppAction.Bar> = .init { dispatchedAction in
            globalDispatcher.dispatch(AppAction.bar(dispatchedAction.action), from: dispatchedAction.dispatcher)
        }

        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, String>()
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )
        nameMiddleware.handleActionFromStateClosure = { _, _, _ in

            return .pure()
        }
        _ = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState() })

        localDispatcher.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareOutputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, String>()
        let composed = nameMiddleware <> IdentityMiddleware()
        var receivedActions = [AppAction]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(4, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareOutputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, String>()
        let composed = nameMiddleware <> IdentityMiddleware()
        var middlewareGetState: (() -> String)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )

        let io = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: .init(), name: "test-unlift-state") })
        io.run(.init { _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }
}

// MARK: - Lifting a single property: Input Action
extension LiftComposedMiddlewareTests {
    func testLiftMiddlewareInputAction_OutputActionsAreForwardedToGlobalContext() {
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }
        let localDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in
            globalDispatcher.dispatch(dispatchedAction.action, from: dispatchedAction.dispatcher)
        }

        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, TestState>()
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar }
            )
        nameMiddleware.handleActionFromStateClosure = { _, _, _ in

            return .pure()
        }
        _ = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState() })

        localDispatcher.dispatch(.bar(.echo), from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher.dispatch(.bar(.delta), from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputAction_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, TestState>()
        let composed = nameMiddleware <> IdentityMiddleware()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputAction_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, TestState>()
        let composed = nameMiddleware <> IdentityMiddleware()
        var middlewareGetState: (() -> TestState)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar }
            )

        let uuid = UUID()
        let io = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: uuid, name: "test-unlift-state") })
        io.run(.init { _ in })

        XCTAssertEqual(TestState(value: uuid, name: "test-unlift-state"), middlewareGetState?())
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }
}

// MARK: - Lifting a single property: Output Action
extension LiftComposedMiddlewareTests {
    func testLiftMiddlewareOutputAction_OutputActionsAreForwardedToGlobalContext() {
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }
        let localDispatcher: AnyActionHandler<AppAction.Bar> = .init { dispatchedAction in
            globalDispatcher.dispatch(AppAction.bar(dispatchedAction.action), from: dispatchedAction.dispatcher)
        }

        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, TestState>()
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) }
            )
        nameMiddleware.handleActionFromStateClosure = { _, _, _ in

            return .pure()
        }
        _ = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState() })

        localDispatcher.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareOutputAction_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, TestState>()
        let composed = nameMiddleware <> IdentityMiddleware()
        var receivedActions = [AppAction]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(4, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareOutputAction_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, TestState>()
        let composed = nameMiddleware <> IdentityMiddleware()
        var middlewareGetState: (() -> TestState)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) }
            )

        let uuid = UUID()
        let io = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: uuid, name: "test-unlift-state") })
        io.run(.init { _ in })

        XCTAssertEqual(TestState(value: uuid, name: "test-unlift-state"), middlewareGetState?())
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }
}

// MARK: - Lifting a single property: State
extension LiftComposedMiddlewareTests {
    func testLiftMiddlewareInputState_OutputActionsAreForwardedToGlobalContext() {

        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }
        let localDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in
            globalDispatcher.dispatch(dispatchedAction.action, from: dispatchedAction.dispatcher)
        }
        let nameMiddleware = MiddlewareMock<AppAction, AppAction, String>()
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                state: { (global: TestState) in global.name }
            )

        localDispatcher.dispatch(.bar(.echo), from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher.dispatch(.bar(.delta), from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction, String>()
        var receivedActions = [AppAction]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return .pure()
        }
        let composed = nameMiddleware <> IdentityMiddleware()
        let generalMiddleware =
            composed.lift(
                state: { (global: TestState) in global.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(4, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }

    func testLiftMiddlewareInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction, String>()
        let composed = nameMiddleware <> IdentityMiddleware()
        var middlewareGetState: (() -> String)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware =
            composed.lift(
                state: { (global: TestState) in global.name }
            )

        _ = generalMiddleware.handle(action: .bar(.alpha), from: .here(), state: { TestState(value: .init(), name: "test-unlift-state") })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
        XCTAssertEqual(generalMiddleware.middlewares.count, 1)
    }
}
