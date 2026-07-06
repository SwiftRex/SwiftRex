// SPDX-License-Identifier: Apache-2.0

extension Behavior {
    /// Folds an array of behaviors into one, in order, using the ``Behavior`` monoid
    /// (``identity`` as the empty element, ``combine(_:_:)`` as the binary operation).
    ///
    /// This is the variadic-collection companion to ``combine(_:_:)`` — handy when composing a
    /// whole app's behaviors from a list (e.g. one lifted child behavior per feature, plus a
    /// navigation reducer and cross-cutting behaviors like logging):
    ///
    /// ```swift
    /// let appBehavior = Behavior.combine([
    ///     homeScope.lifted,
    ///     detailScope.lifted,
    ///     navigationReducer,
    ///     loggingBehavior,
    /// ])
    /// ```
    ///
    /// An empty array yields ``identity`` (the no-op behavior).
    ///
    /// - Parameter behaviors: The behaviors to fold, applied left-to-right.
    /// - Returns: A single behavior equivalent to `behaviors[0] <> behaviors[1] <> …`.
    public static func combine(_ behaviors: [Behavior]) -> Behavior {
        behaviors.reduce(.identity, Behavior.combine)
    }
}
