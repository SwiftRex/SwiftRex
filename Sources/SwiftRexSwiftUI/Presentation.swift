// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
/// A three-stage presentation lifecycle — the pure state-machine home for a modal / sheet / destination,
/// so the *dismissal frame* is a modeled state rather than a view-layer hack.
///
/// ```
/// dismissed ──present(x)──▶ presented(x) ──dismiss──▶ dismissing(last: x) ──dismiss──▶ dismissed
/// ```
///
/// `dismissing(last:)` keeps the last presented value, so the view renders **unchanged** while SwiftUI
/// animates the sheet out; the `dismissing → dismissed` step is driven by SwiftUI's `onDismiss`
/// completion (a real lifecycle event, `PresentationAction.dismissed`), never a timer. Prefer this over `Wrapped?` for animated
/// presentation — exactly as you prefer ``Loading`` over a bool + spinner for async state, because the
/// in-between stage is real and deserves a name.
///
/// This is a **pure** state type (no SwiftUI): it reduces on any platform and tests without a view.
///
/// ## Functor, not Monad
///
/// `Presentation` is a `Functor` (``map(_:)``) — remap the wrapped value, preserve the stage. It is
/// **not** a lawful `Monad`: the stage is a lifecycle position orthogonal to the payload, so a `bind`
/// would have to combine two stages and right identity fails (`dismissing(w).flatMap(pure) ≠
/// dismissing(w)`). You *observe* a presentation; you don't *sequence* it.
public enum Presentation<Wrapped> {
    /// Presented and live.
    case presented(Wrapped)
    /// Animating out — still showing `last` until the dismissal completes.
    case dismissing(last: Wrapped)
    /// Gone.
    case dismissed
}

extension Presentation {
    /// The value the view renders — the payload of `presented` **and** `dismissing` (so content is
    /// stable through the dismiss animation), `nil` when `dismissed`.
    ///
    /// Writable so a lifted child reducer can mutate the presented value in place, preserving the stage.
    /// Setting `nil` is ignored (there is no payload to remove — dismiss via ``dismiss()``); setting a
    /// value while `dismissed` is ignored (present via `.presented`).
    public var wrapped: Wrapped? {
        get {
            switch self {
            case let .presented(value), let .dismissing(value): value
            case .dismissed: nil
            }
        }
        set {
            guard let newValue else { return }
            switch self {
            case .presented: self = .presented(newValue)
            case .dismissing: self = .dismissing(last: newValue)
            case .dismissed: break
            }
        }
    }

    /// `true` only while `presented` — the presentation binding's `get`. It goes `false` the moment
    /// dismissal begins, which is what makes SwiftUI start the out-animation while `wrapped` still holds
    /// the last value.
    public var isPresented: Bool {
        if case .presented = self { true } else { false }
    }

    /// Functor `map` — remap the wrapped value, preserving the stage.
    public func map<Mapped>(_ transform: (Wrapped) -> Mapped) -> Presentation<Mapped> {
        switch self {
        case let .presented(value): .presented(transform(value))
        case let .dismissing(value): .dismissing(last: transform(value))
        case .dismissed: .dismissed
        }
    }

    /// Start dismissing: `presented → dismissing(last:)`, keeping the value on screen while SwiftUI animates
    /// out. Unchanged when already `dismissing` or `dismissed` — the end of the dismissal is `PresentationAction.dismissed`
    /// (SwiftUI's `onDismiss`), which sets `.dismissed`.
    public func dismiss() -> Presentation {
        switch self {
        case let .presented(value): .dismissing(last: value)
        case .dismissing, .dismissed: self
        }
    }
}

extension Presentation: Sendable where Wrapped: Sendable {}
extension Presentation: Equatable where Wrapped: Equatable {}
extension Presentation: Hashable where Wrapped: Hashable {}

#endif
