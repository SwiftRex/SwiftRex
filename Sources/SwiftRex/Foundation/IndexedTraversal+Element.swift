// SPDX-License-Identifier: Apache-2.0

import CoreFP

extension IndexedTraversal where I: Hashable & Sendable, S: Sendable, A: Sendable {
    /// Derives an ``AffineTraversal`` addressing the single focus tagged with `id`.
    ///
    /// `preview` finds the `(id, focus)` pair; `setMut` writes back through this traversal's
    /// `modifyMut`, touching only the matching focus. Used by `liftEach` to lift a per-element
    /// mutation/effect for one element of an `IndexedTraversal`-described container.
    func element(_ id: I) -> AffineTraversal<S, A> {
        AffineTraversal(
            preview: { @Sendable whole in self.getAll(whole).first { $0.0 == id }?.1 },
            setMut: { @Sendable whole, newValue in
                self.modifyMut(&whole) { index, focus in if index == id { focus = newValue } }
            }
        )
    }
}
