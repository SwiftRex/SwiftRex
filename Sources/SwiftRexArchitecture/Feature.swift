#if canImport(Observation) && canImport(SwiftUI)
import Observation
import SwiftRex
import SwiftRexSwiftUI
import SwiftUI

/// The role a `@Feature` plays in its module — the single axis that distinguishes the module's
/// public entry point from the screens composed inside it.
///
/// A module is a `@Feature` marked ``publicEntryPoint`` — the only thing the outside world sees.
/// The screens it composes are `@Feature`s marked ``internalScreen`` — their `View`, `ViewModel`,
/// `ViewState`, and `ViewAction` never cross the module boundary. The role controls only the
/// access level of the members the macro synthesises (`view`, `initialState`); everything erased
/// (the view layer) stays `internal`/`private` regardless.
public enum FeatureRole: Sendable {
    /// The module's public entry point — `view(store:environment:)` and `initialState(with:)` are
    /// generated `public`, so the composing app can render and seed the module. `State`/`Action`/
    /// `Environment`/`Input` are declared `public` by the author (they must be liftable).
    case publicEntryPoint

    /// A screen internal to a module — the generated members are `internal`. Only the module's own
    /// root composes it, so nothing needs to cross the package boundary.
    case internalScreen
}
#endif
