@testable import SwiftRex
import XCTest

class LiftToCollectionMiddlewareTests: XCTestCase {
}

// MARK: - Lifting all 3 properties
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension LiftToCollectionMiddlewareTests {
    func testLiftToCollectionMiddlewareInputActionOutputActionInputState_OutputActionsAreForwardedToGlobalContext() {
        var globalReceived: [DispatchedAction<AppAction>] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action in globalReceived.append(action) }
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, AppState.Item>()

        let generalMiddleware: LiftToCollectionMiddleware<
            AppAction,
            AppAction,
            AppState,
            [AppState.Item],
            IsoMiddlewareMock<AppAction.Bar, AppState.Item>
        > = nameMiddleware.liftToCollection(
            inputAction: { (inputAction: AppAction) in
                inputAction.scoped
            }, outputAction: { elementIDAction in
                AppAction.scoped(elementIDAction)
            }, state: { (appState: AppState) in
                appState.list
            }
        )

        nameMiddleware.handleActionFromStateReturnValue = IO { output in
            output.dispatch(.echo, from: .here())
        }

        generalMiddleware
            .handle(action: .foo,
                    from: .here(),
                    state: { AppState(testState: TestState(), list: [AppState.Item(id: 1, name: "One")]) })
            .run(globalDispatcher)
        generalMiddleware
            .handle(action: .scoped(.init(id: 1, action: .alpha)),
                    from: .here(),
                    state: { AppState(testState: TestState(), list: [AppState.Item(id: 1, name: "One")]) })
            .run(globalDispatcher)

        let expectedActionsOnGlobalContext: [AppAction] = [.scoped(.init(id: 1, action: .echo))]
        XCTAssertEqual(globalReceived.map(\.action), expectedActionsOnGlobalContext)
    }

    func testLiftToCollectionMiddlewareInputActionOutputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, AppState.Item>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromStateClosure = { action, _, _ in
            receivedActions.append(action)
            return IO.pure()
        }

        let generalMiddleware: LiftToCollectionMiddleware<
            AppAction, AppAction, AppState, [AppState.Item], IsoMiddlewareMock<AppAction.Bar, AppState.Item>
        > = nameMiddleware.liftToCollection(
            inputAction: { (inputAction: AppAction) in
                inputAction.scoped
            }, outputAction: { elementIDAction in
                AppAction.scoped(elementIDAction)
            }, state: { (appState: AppState) in
                appState.list
            }
        )

        let appState = AppState(testState: TestState(), list: [AppState.Item(id: 1, name: "One"), AppState.Item(id: 2, name: "Two")])

        _ = generalMiddleware.handle(action: .scoped(.init(id: 1, action: .alpha)), from: .here(), state: { appState })
        _ = generalMiddleware.handle(action: .scoped(.init(id: 2, action: .bravo)), from: .here(), state: { appState })
        _ = generalMiddleware.handle(action: .scoped(.init(id: 3, action: .charlie)), from: .here(), state: { appState })

        XCTAssertEqual(2, nameMiddleware.handleActionFromStateCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.alpha, .bravo]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftToCollectionMiddlewareInputActionOutputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, AppState.Item>()
        var middlewareGetState: (() -> AppState.Item)?
        nameMiddleware.handleActionFromStateClosure = { _, _, getState in
            middlewareGetState = getState
            return .pure()
        }

        let generalMiddleware: LiftToCollectionMiddleware<
            AppAction, AppAction, AppState, [AppState.Item], IsoMiddlewareMock<AppAction.Bar, AppState.Item>
        > = nameMiddleware.liftToCollection(
            inputAction: { (inputAction: AppAction) in
                inputAction.scoped
            }, outputAction: { elementIDAction in
                AppAction.scoped(elementIDAction)
            }, state: { (appState: AppState) in
                appState.list
            }
        )

        generalMiddleware
            .handle(action: .scoped(.init(id: 1, action: .alpha)),
                    from: .here(),
                    state: { AppState(testState: TestState(), list: [AppState.Item(id: 1, name: "One")]) })
            .run(.init { _ in })
        XCTAssertEqual("One", middlewareGetState?().name)
    }
}

// MARK: - Lifting all 3 properties at once where Input Action == Output Action
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension LiftToCollectionMiddlewareTests {
    func testLiftToCollectionMiddlewareInputActionIsEqualToOutputAction_OutputActionsAreForwardedToGlobalContext() {
        var globalReceived: [DispatchedAction<AppAction>] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action in globalReceived.append(action) }
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, AppState.Item>()

        let generalMiddleware: LiftToCollectionMiddleware<
            AppAction, AppAction, AppState, [AppState.Item], IsoMiddlewareMock<AppAction.Bar, AppState.Item>
        > = nameMiddleware.liftToCollection(action: \AppAction.scoped,
                                            stateCollection: \AppState.list)

        nameMiddleware.handleActionFromStateReturnValue = IO { output in
            output.dispatch(.echo, from: .here())
        }

        generalMiddleware
            .handle(action: .foo,
                    from: .here(),
                    state: { AppState(testState: TestState(), list: [AppState.Item(id: 1, name: "One")]) })
            .run(globalDispatcher)
        generalMiddleware
            .handle(action: .scoped(.init(id: 1, action: .alpha)),
                    from: .here(),
                    state: { AppState(testState: TestState(), list: [AppState.Item(id: 1, name: "One")]) })
            .run(globalDispatcher)

        let expectedActionsOnGlobalContext: [AppAction] = [.scoped(.init(id: 1, action: .echo))]
        XCTAssertEqual(globalReceived.map(\.action), expectedActionsOnGlobalContext)
    }
}
