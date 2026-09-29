// SPDX-License-Identifier: Apache-2.0

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@Feature(strategy:)` — the feature macro.
///
/// - `MemberAttributeMacro` — adds `@ApplyOptics(recursively: true)` to **every** nested domain-state
///   struct/enum (`State`, `Action`, `ViewAction`, and any other nested type — a `Route`, a sub-state —
///   recursively down its own tree), skipping the non-state members `Environment`/`Content`/`Input` and
///   the `ViewState` view projection. A user attribute (`@ApplyOptics`/`@Lenses`/`@Prisms`/`@NoOptics`) on a
///   nested type wins. State declared in an *extension* of the feature isn't visible to the macro —
///   annotate that extension with `@ApplyOptics(recursively: true)` directly.
/// - `MemberMacro`          — synthesises `initialState(with:)` (Void seed) when not written, and
///   generates `view(store:environment:) -> some View` (when a `Content` view exists) handing `Content`
///   an `ObservableStore` (built once per view identity) over an environment-aware projection, signalling
///   through `strategy:` (default `.automatic`: Observation on iOS 17+, Combine below; nothing is gated).
/// - `ExtensionMacro`       — generates the `Feature` conformance when the type has a view (a `Content`,
///   or a hand-written `view`); a view-less feature is a behavior only and gets no `Feature`
///   conformance. Nothing is availability-gated: the store picks Observation or Combine at runtime.
///
/// **Access follows the `enum`'s own modifier** — a `public enum` gets `public` members; a plain `enum`
/// keeps them `internal` — read from the declaration, exactly like `@BoundTo`. `ViewState`/
/// `ViewAction`/`Content` stay whatever the author wrote and are hidden behind `view()`'s opaque return.
public struct FeatureMacro: MemberAttributeMacro, MemberMacro, ExtensionMacro {
    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(EnumDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: FeatureDiagnostic.mustBeEnum))
            return []
        }

        let access = accessModifier(from: declaration.modifiers)
        var members: [DeclSyntax] = []

        // `initialState(with:)` defaults to `State.init()` for the common Void-seed case. Only
        // synthesise when there is a nested `State`, no custom `Input` seed, and no user override.
        if hasNestedType("State", in: declaration),
           !hasNestedType("Input", in: declaration),
           !hasInitialState(in: declaration) {
            members.append("\(raw: access)static func initialState(with _: Void) -> State { .init() }")
        }

        // The view projection layer is optional. When the author omits `ViewState`/`ViewAction`, we
        // alias them to `State`/`Action` so the view (and `@BoundTo`) see the domain types directly —
        // no distinct view state, no map boilerplate, no projection indirection. Declare a `ViewState`
        // struct only when the UI needs a different shape (e.g. an Int formatted as a String).
        if !hasNestedType("ViewState", in: declaration) {
            members.append("\(raw: access)typealias ViewState = State")
        }
        if !hasNestedType("ViewAction", in: declaration) {
            members.append("\(raw: access)typealias ViewAction = Action")
        }
        // `Environment` is optional too: a feature with no dependencies can omit it and gets `Void`.
        if !hasNestedType("Environment", in: declaration) {
            members.append("\(raw: access)typealias Environment = Void")
        }

        // The erased entry — generated only when the feature has a `Content` view.
        if hasNestedType("Content", in: declaration) {
            members.append(viewMember(access: access, node: node, declaration: declaration))
        }

        return members
    }

    /// Builds `view(store:environment:)`. The view gets an `ObservableStore` built once per view identity
    /// (`ObservableStoreHost`), signalling through `strategy:` (chosen at runtime by the store, so ungated).
    /// When a `ViewState` struct / `ViewAction` enum exists the store is projected through the (env-aware)
    /// maps — buffered before the map when the feature's `State` is `Equatable`, picked by overload
    /// resolution in `ObservableStore.feature` — otherwise the feature's store is observed as-is, with an
    /// unmapped axis in a mixed feature falling back to identity.
    private static func viewMember(
        access: String,
        node: AttributeSyntax,
        declaration: some DeclGroupSyntax
    ) -> DeclSyntax {
        let strategy = strategyName(node)

        let projectsState = hasNestedStruct("ViewState", in: declaration)
        let projectsAction = hasNestedEnum("ViewAction", in: declaration)
        let source: String
        if projectsState || projectsAction {
            let stateMap = projectsState
                ? "mapState"
                : "Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in { $0 } }"
            let actionMap = projectsAction
                ? "mapAction"
                : "Reader<Environment, @Sendable (ViewAction) -> Action> { _ in { $0 } }"
            source = "ObservableStore<ViewAction, ViewState>.feature(store, environment: environment, " +
                "action: \(actionMap), state: \(stateMap), strategy: .\(strategy))"
        } else {
            source = "ObservableStore<ViewAction, ViewState>.feature(store, strategy: .\(strategy))" // no view layer
        }
        // The store parameter is `any StoreType<Action, State>` (an existential — a CONCRETE type),
        // not `some StoreType<…>` (a generic parameter). A generic method returning `some View`
        // cannot bind the `ViewFactory.Body` associated type, so the feature couldn't conform to
        // `Feature`; the existential can. Callers are unaffected — a `Store` boxes into it.
        return """
        @MainActor \(raw: access)static func view(
            store: any StoreType<Action, State>,
            environment: Environment
        ) -> some View {
            ObservableStoreHost {
                \(raw: source)
            } content: {
                Content(viewStore: $0)
            }
        }
        """
    }

    // MARK: - ExtensionMacro

    /// Generates the protocol conformance. A feature that builds a view — it has a `Content` (the macro
    /// generates `view()`) or a hand-written `view` — conforms to `Feature`; a view-less feature is a
    /// behavior only and conforms to `HasBehavior`. Ungated, like the generated `view()` — the store picks
    /// Observation or Combine at runtime.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(EnumDeclSyntax.self) else { return [] }

        // Only a view-bearing feature (a `Content`, or a hand-written `view`) conforms — to `Feature`. A
        // view-less feature is a behavior only and is NOT auto-conformed: `Feature` refines
        // `HasBehavior`, and a single extension role cannot both list `Feature` (needed here) and emit a
        // bare `HasBehavior` (the compiler rejects both co-listing the refinement pair AND emitting an
        // unlisted super protocol). A view-less feature already has `behavior()`, so it can declare
        // `: HasBehavior` itself in one line when it needs to be used generically.
        guard hasNestedType("Content", in: declaration) || hasFunction("view", in: declaration) else {
            return []
        }
        let conformance: DeclSyntax = "extension \(raw: type.trimmedDescription): Feature {}"
        return conformance.as(ExtensionDeclSyntax.self).map { [$0] } ?? []
    }

    // MARK: - MemberAttributeMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // `ViewState` is the view projection, not domain state: never optics.
        if let structDecl = member.as(StructDeclSyntax.self), structDecl.name.text == "ViewState" {
            return []
        }

        // Every other nested struct/enum is treated as domain state and gets recursive optics
        // (`@ApplyOptics(recursively: true)` — `@Lenses` for structs, `@Prisms` for enums, all the way
        // down its own nested tree) — not just `State`/`Action`. A nested `Route`, a sub-state struct,
        // an inner enum: all covered from the one `@Feature` annotation. State the user adds in an
        // *extension* of the feature isn't visible here — annotate that extension with
        // `@ApplyOptics(recursively: true)` yourself.
        let name: String
        let attributes: AttributeListSyntax
        if let structDecl = member.as(StructDeclSyntax.self) {
            name = structDecl.name.text
            attributes = structDecl.attributes
        } else if let enumDecl = member.as(EnumDeclSyntax.self) {
            name = enumDecl.name.text
            attributes = enumDecl.attributes
        } else {
            return []
        }

        // Non-state framework members: dependencies, the view, and the seed carry no optics.
        guard !["Environment", "Content", "Input"].contains(name) else { return [] }

        // Respect a user-written optics choice — `@ApplyOptics`/`@Lenses`/`@Prisms` (custom options) or
        // `@NoOptics` (opt this type out).
        let userChoseOptics = ["ApplyOptics", "Lenses", "Prisms", "NoOptics"]
            .contains { hasAttribute($0, on: attributes) }
        return userChoseOptics ? [] : ["@ApplyOptics(recursively: true)"]
    }

    // MARK: - Private

    /// The member-access case name of a labeled argument, e.g. `strategy: .combine` → `"combine"`.
    private static func argumentCase(_ label: String, in node: AttributeSyntax) -> String? {
        guard let args = node.arguments?.as(LabeledExprListSyntax.self) else { return nil }
        for arg in args where arg.label?.text == label {
            return arg.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
        }
        return nil
    }

    /// The access modifier the members should carry, read from the attached `enum` — `"public "`,
    /// `"package "`, `""` (internal), etc. Matches `@BoundTo`: the declaration's own access
    /// drives the generated members, so there is no `type:` argument.
    private static func accessModifier(from modifiers: DeclModifierListSyntax) -> String {
        modifiers
            .first(where: {
                switch $0.name.tokenKind {
                case .keyword(.public),
                     .keyword(.package),
                     .keyword(.internal),
                     .keyword(.fileprivate),
                     .keyword(.open):
                    true
                default:
                    false
                }
            })
            .map { "\($0.name.text) " } ?? ""
    }

    /// The `strategy:` case name; defaults to `"automatic"`.
    private static func strategyName(_ node: AttributeSyntax) -> String {
        argumentCase("strategy", in: node) ?? "automatic"
    }

    private static func hasAttribute(_ name: String, on attributes: AttributeListSyntax) -> Bool {
        attributes.contains {
            $0.as(AttributeSyntax.self)?
                .attributeName
                .as(IdentifierTypeSyntax.self)?
                .name.text == name
        }
    }

    private static func hasNestedType(_ name: String, in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains { member in
            let decl = member.decl
            return decl.as(StructDeclSyntax.self)?.name.text == name
                || decl.as(EnumDeclSyntax.self)?.name.text == name
                || decl.as(ClassDeclSyntax.self)?.name.text == name
                || decl.as(ActorDeclSyntax.self)?.name.text == name
                || decl.as(TypeAliasDeclSyntax.self)?.name.text == name
        }
    }

    private static func hasNestedStruct(_ name: String, in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains { $0.decl.as(StructDeclSyntax.self)?.name.text == name }
    }

    private static func hasNestedEnum(_ name: String, in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains { $0.decl.as(EnumDeclSyntax.self)?.name.text == name }
    }

    private static func hasInitialState(in declaration: some DeclGroupSyntax) -> Bool {
        hasFunction("initialState", in: declaration)
    }

    private static func hasFunction(_ name: String, in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains {
            $0.decl.as(FunctionDeclSyntax.self)?.name.text == name
        }
    }
}
