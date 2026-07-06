// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

@Suite("Behavior liftEach")
@MainActor
struct BehaviorLiftEachTests {
    private struct Timer: Identifiable, Equatable, Sendable {
        let id: Int
        var count: Int = 0
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

    private static let timerPrism = CoreFP.prism(
        preview: { (a: AppAction) -> ElementAction<Int, TimerAction>? in
            guard case let .timer(ea) = a else { return nil }
            return ea
        },
        review: { AppAction.timer($0) }
    )

    private func poll(until condition: @MainActor () -> Bool) async {
        for _ in 0..<1_000 where !condition() {
            await Task.yield()
        }
    }

    @Test func broadcastsMutationToEveryElement() {
        let perElement = Behavior<TimerAction, Timer, Void>.handle { action, _ in
            switch action {
            case .tick: .reduce { $0.count += 1 }
            case .didTick: .doNothing
            }
        }
        let lifted = perElement.liftEach(
            action: { if case .tickAll = $0 { TimerAction.tick } else { nil } },
            embed: { local, id in AppAction.timer(ElementAction(id, action: local)) },
            stateCollection: \AppState.timers
        )
        let store = Store(initial: AppState(timers: [Timer(id: 1), Timer(id: 2), Timer(id: 3)]), behavior: lifted, environment: ())
        store.dispatch(.tickAll)
        #expect(store.state.timers.map(\.count) == [1, 1, 1])
    }

    // The recommended composition: liftEach fans out the trigger; each element's effect emits an
    // addressed action that a combined liftCollection routes back to that element.
    @Test func fansOutEffectsThatLoopBackPerElement() async {
        let perElement = Behavior<TimerAction, Timer, Void>.handle { action, _ in
            switch action {
            case .tick: .produce { _ in Effect.just(.didTick) }
            case .didTick: .reduce { $0.ticked = true }
            }
        }
        let lifted = Behavior.combine(
            perElement.liftEach(
                action: { if case .tickAll = $0 { TimerAction.tick } else { nil } },
                embed: { local, id in AppAction.timer(ElementAction(id, action: local)) },
                stateCollection: \AppState.timers
            ),
            perElement.liftCollection(action: Self.timerPrism, stateCollection: \AppState.timers)
        )
        let store = Store(initial: AppState(timers: [Timer(id: 1), Timer(id: 2)]), behavior: lifted, environment: ())
        store.dispatch(.tickAll)
        await poll { store.state.timers.allSatisfy(\.ticked) }
        #expect(store.state.timers.map(\.ticked) == [true, true])
    }
}
