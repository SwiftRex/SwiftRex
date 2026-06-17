import CoreFP
import DataStructure
@testable import SwiftRex
import Testing

private enum AppAction: Equatable, Sendable {
    case counter(Int)
    case other(String)
}

extension AppAction: Prismatic {
    struct Prisms: Sendable {
        let counter = Prism<AppAction, Int>(
            preview: { if case .counter(let value) = $0 { value } else { nil } },
            review: AppAction.counter
        )
        let other = Prism<AppAction, String>(
            preview: { if case .other(let value) = $0 { value } else { nil } },
            review: AppAction.other
        )
    }
    static let prism = Prisms()
}

@Suite("Middleware — PrismKeyPath action lifting (generated twins)")
@MainActor
struct MiddlewarePrismKeyPathLiftTests {
    // Middleware re-embeds the action its effect produces through the recovered prism's `review`,
    // so the looped-back action is `.counter(7)` and the reducer adds it.
    @Test func liftActionViaPrismKeyPathRewrapsProducedActions() async {
        let producing = Middleware<Int, Int, Void>.handle { action, _ in
            action == 0 ? Reader { _ in Effect.just(7) } : Reader { _ in .empty }
        }
        let recorder = Reducer<Int, Int>.reduce { action, state in state += action }
        let liftedReducer: Reducer<AppAction, Int> = recorder.lift(action: \.counter)
        let liftedMiddleware: Middleware<AppAction, Int, Void> = producing.liftAction(\.counter)
        let behavior = Behavior(reducer: liftedReducer, middleware: liftedMiddleware)
        let store = Store(initial: 0, behavior: behavior, environment: ())

        store.dispatch(.counter(0)) // reducer adds 0; effect produces .counter(7), loops back, adds 7
        for _ in 0..<50 where store.state != 7 { await Task.yield() }
        #expect(store.state == 7)
    }
}
