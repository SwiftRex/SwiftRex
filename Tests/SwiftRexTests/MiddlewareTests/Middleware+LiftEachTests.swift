import CoreFP
import DataStructure
@testable import SwiftRex
import Testing

private struct Timer: Identifiable, Equatable, Sendable {
    let id: Int
    var ticked: Bool = false
}

private struct AppState: Equatable, Sendable {
    var timers: [Timer]
}

private enum TimerAction: Sendable {
    case tick
    case didTick
}

private enum AppAction: Sendable {
    case tickAll
    case timer(ElementAction<Int, TimerAction>)
}

private let timerPrism = CoreFP.prism(
    preview: { (a: AppAction) -> ElementAction<Int, TimerAction>? in
        guard case .timer(let ea) = a else { return nil }
        return ea
    },
    review: { AppAction.timer($0) }
)

@Suite("Middleware liftEach")
@MainActor
struct MiddlewareLiftEachTests {
    private func poll(until condition: @MainActor () -> Bool) async {
        for _ in 0..<1_000 where !condition() { await Task.yield() }
    }

    // Middleware fans out the trigger as effects; each element's effect loops back an addressed
    // action that a liftCollection-lifted Reducer records — proving parity with Behavior.liftEach.
    @Test func fansOutEffectsThatLoopBackPerElement() async {
        let perElement = Middleware<TimerAction, Timer, Void>.handle { action, _ in
            switch action {
            case .tick: Reader { _ in Effect.just(.didTick) }
            case .didTick: Reader { _ in .empty }
            }
        }
        let recorder = Reducer<TimerAction, Timer>.reduce { action, timer in
            if case .didTick = action { timer.ticked = true }
        }
        let behavior = Behavior(
            reducer: recorder.liftCollection(action: { timerPrism.preview($0) }, stateCollection: \AppState.timers),
            middleware: perElement.liftEach(
                action: { if case .tickAll = $0 { return TimerAction.tick } else { return nil } },
                embed: { local, id in AppAction.timer(ElementAction(id, action: local)) },
                stateCollection: \AppState.timers
            )
        )
        let store = Store(initial: AppState(timers: [Timer(id: 1), Timer(id: 2)]), behavior: behavior, environment: ())
        store.dispatch(.tickAll)
        await poll { store.state.timers.allSatisfy(\.ticked) }
        #expect(store.state.timers.map(\.ticked) == [true, true])
    }
}
