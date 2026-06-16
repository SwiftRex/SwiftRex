/// The scheduling id of a collection-lifted element's effect: the element's id paired with the
/// user's own effect id.
///
/// When a `Behavior` is lifted into a collection, each element's effect-scheduling id is wrapped
/// in this composite so element A's `.debounce(id: .fetch)` is independent of element B's — while
/// the user keeps owning the inner id. Cross-collection / cross-feature collisions remain the
/// user's responsibility (use distinct id enums), exactly as for un-lifted effects.
package struct ElementScopedID: Hashable, Sendable {
    package let element: AnyHashableSendable
    package let inner: AnyHashableSendable
}

extension EffectScheduling {
    /// Re-tags the id-carrying policies with `ElementScopedID(element:, inner: existing)`.
    /// `.immediately` (which carries no id) is returned unchanged.
    package func scopedToElement(_ element: AnyHashableSendable) -> EffectScheduling {
        switch self {
        case .immediately:                    .immediately
        case .replacing(let id):              .replacing(id: scoped(element, id))
        case let .debounce(id, delay):        .debounce(id: scoped(element, id), delay: delay)
        case let .throttle(id, interval):     .throttle(id: scoped(element, id), interval: interval)
        case .cancelInFlight(let id):         .cancelInFlight(id: scoped(element, id))
        }
    }
}

private func scoped(_ element: AnyHashableSendable, _ inner: AnyHashableSendable) -> AnyHashableSendable {
    AnyHashableSendable(ElementScopedID(element: element, inner: inner))
}

extension Effect {
    /// Scopes every component's scheduling id to `element` (see ``ElementScopedID``).
    package func scopedToElement(_ element: AnyHashableSendable) -> Effect {
        Effect(components: components.map {
            Component(subscribe: $0.subscribe, scheduling: $0.scheduling.scopedToElement(element))
        })
    }
}
