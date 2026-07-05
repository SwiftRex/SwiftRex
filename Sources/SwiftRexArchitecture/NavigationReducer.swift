#if canImport(Observation) && canImport(SwiftUI)
import CoreFP
import SwiftRex

// MARK: - Navigation action vocabulary

/// The standard operations on a **stack** (`[Route]`) navigation slice. Embed one case of this in
/// your feature's `Action` (e.g. `case nav(StackNavigation<AppRoute>)`) and reduce it with
/// ``Behavior/navigationStack(_:action:allow:)``.
public enum StackNavigation<Route: Hashable & Sendable>: Sendable {
    case push(Route)
    case pop
    case popToRoot
    /// Replace the whole path — what `NavigationStack(path:)`'s binding delivers on any change
    /// (push, back-swipe, pop-to-root), so a single case covers interactive navigation.
    case setPath([Route])
}

/// The standard operations on a **modal / optional** (`Item?`) navigation slice — present sets the
/// slice to `.some`, dismiss clears it. Reduce with ``Behavior/navigationItem(_:action:allow:)``.
public enum ModalNavigation<Item: Sendable>: Sendable {
    case present(Item)
    case dismiss
}

/// The operation on a **selection** (1-of-N) navigation slice. Reduce with
/// ``Behavior/navigationSelection(_:action:allow:)``.
public enum SelectionNavigation<Selection: Sendable>: Sendable {
    case select(Selection)
}

// MARK: - Navigation reducers

extension Behavior {
    /// A behavior that reduces ``StackNavigation`` operations into a `[Route]` slice of state.
    ///
    /// Add it to your app's behavior list (`Behavior.combine([…, navigationStack(…)])`). The default
    /// is to **apply** every operation; pass `allow` to veto or gate one (return `false` to block —
    /// e.g. refuse to pop while a form is dirty). Navigation stays a function of state: a blocked
    /// operation simply leaves the path unchanged, and the `NavigationStack` binding re-presents it.
    ///
    /// ```swift
    /// Behavior.navigationStack(\.path, action: \.nav)                         // always apply
    /// Behavior.navigationStack(\.path, action: \.nav) { op, s in !s.isDirty } // veto pop while dirty
    /// ```
    public static func navigationStack<Route: Hashable & Sendable>(
        _ path: WritableKeyPath<State, [Route]>,
        action navigation: PrismKeyPath<Action, StackNavigation<Route>>,
        allow: (@Sendable (StackNavigation<Route>, State) -> Bool)? = nil
    ) -> Behavior where Action: Prismatic {
        let preview = Prism(navigation).preview
        return .reduce { action, state in
            guard let op = preview(action), allow?(op, state) != false else { return }
            switch op {
            case .push(let route):  state[keyPath: path].append(route)
            case .pop:              if !state[keyPath: path].isEmpty { state[keyPath: path].removeLast() }
            case .popToRoot:        state[keyPath: path].removeAll()
            case .setPath(let new): state[keyPath: path] = new
            }
        }
    }

    /// A behavior that reduces ``ModalNavigation`` into an optional (`Item?`) slice — present sets
    /// `.some`, dismiss clears. `allow` gates an operation (return `false` to block, e.g. refuse to
    /// dismiss with unsaved edits). For sheets/covers/popovers driven by ``StoreType/item(_:dismiss:)``.
    public static func navigationItem<Item: Sendable>(
        _ item: WritableKeyPath<State, Item?>,
        action navigation: PrismKeyPath<Action, ModalNavigation<Item>>,
        allow: (@Sendable (ModalNavigation<Item>, State) -> Bool)? = nil
    ) -> Behavior where Action: Prismatic {
        let preview = Prism(navigation).preview
        return .reduce { action, state in
            guard let op = preview(action), allow?(op, state) != false else { return }
            switch op {
            case .present(let value): state[keyPath: item] = value
            case .dismiss:            state[keyPath: item] = nil
            }
        }
    }

    /// A behavior that reduces ``SelectionNavigation`` into a selection slice — for
    /// `TabView(selection:)` / split view. `allow` gates a change (return `false` to block, e.g.
    /// refuse to leave a tab mid-task). Unlike modal dismiss, selecting is a normal state change.
    public static func navigationSelection<Selection: Sendable>(
        _ selection: WritableKeyPath<State, Selection>,
        action navigation: PrismKeyPath<Action, SelectionNavigation<Selection>>,
        allow: (@Sendable (SelectionNavigation<Selection>, State) -> Bool)? = nil
    ) -> Behavior where Action: Prismatic {
        let preview = Prism(navigation).preview
        return .reduce { action, state in
            guard let op = preview(action), allow?(op, state) != false else { return }
            switch op {
            case .select(let value): state[keyPath: selection] = value
            }
        }
    }
}
#endif
