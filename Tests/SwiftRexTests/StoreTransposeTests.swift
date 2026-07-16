// SPDX-License-Identifier: Apache-2.0

import CoreFP
@testable import SwiftRex
import Testing

private enum ChildAction: Sendable, Equatable { case bump }
private struct Child: Sendable, Equatable { var n = 0 }
private enum AppAction: Sendable, Equatable { case child(ChildAction); case dismiss }
extension AppAction: Prismatic {
    struct Prisms: Sendable {
        let child = Prism<AppAction, ChildAction>(preview: { if case let .child(v) = $0 { v } else { nil } }, review: AppAction.child)
    }
    static let prism = Prisms()
}
private struct App: Sendable, Equatable { var child: Child? }

@Suite("StoreProjection.transpose — swap Store<T?> → Store<T>?") @MainActor
struct StoreTransposeTests {
    @Test func presentInvertsToUnwrappedStore() {
        let store = Store<AppAction, App, Void>(initial: App(child: Child(n: 3)), behavior: .identity, environment: ())
        let opt = store.projection(.action(AppAction.prism.child).state(\App.child))  // StoreProjection<ChildAction, Child?>
        if let unwrapped = opt.transpose() {
            #expect(unwrapped.state == Child(n: 3))
        } else {
            Issue.record("expected .some(store) while present")
        }
    }

    @Test func absentInvertsToNil() {
        let store = Store<AppAction, App, Void>(initial: App(child: nil), behavior: .identity, environment: ())
        let unwrapped = store.projection(.action(AppAction.prism.child).state(\App.child)).transpose()
        #expect(unwrapped == nil)
    }

    @Test func retainsLastValueAcrossDismiss() {
        // The unwrapped store must stay valid (no crash) on the transient frame the source reads nil,
        // falling back to the value captured at transpose-time.
        let clearing = Behavior<AppAction, App, Void>.reduce { action, state in
            if case .dismiss = action { state.child = nil }
        }
        let store = Store<AppAction, App, Void>(initial: App(child: Child(n: 5)), behavior: clearing, environment: ())
        if let unwrapped = store.projection(.action(AppAction.prism.child).state(\App.child)).transpose() {
            #expect(unwrapped.state == Child(n: 5))
            store.dispatch(.dismiss)                 // child → nil
            #expect(unwrapped.state == Child(n: 5))  // retained, no crash
            #expect(store.state.child == nil)        // source really cleared
        } else {
            Issue.record("expected .some(store) while present")
        }
    }
}
