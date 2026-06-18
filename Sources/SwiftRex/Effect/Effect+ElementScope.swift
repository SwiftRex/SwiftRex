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
    /// Re-tags the id (if any) with `ElementScopedID(element:, inner: existing)`, leaving every
    /// other knob — `delay`, `coalesce`, `exclusive`, the cancel-only flag — untouched. Anonymous
    /// scheduling (no id) is returned unchanged.
    package func scopedToElement(_ element: AnyHashableSendable) -> EffectScheduling {
        guard let id else { return self }
        var copy = self
        copy.id = AnyHashableSendable(ElementScopedID(element: element, inner: id))
        return copy
    }
}

extension Effect {
    /// Scopes every component's scheduling id to `element` (see ``ElementScopedID``).
    package func scopedToElement(_ element: AnyHashableSendable) -> Effect {
        Effect(components: components.map {
            Component(subscribe: $0.subscribe, channel: $0.channel, scheduling: $0.scheduling.scopedToElement(element))
        })
    }
}
