// SPDX-License-Identifier: Apache-2.0

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@Feature(strategy:)` — the feature macro.
///
/// - `MemberAttributeMacro` — adds `@ApplyOptics(recursively: true)` to **every** nested domain-state
///   struct/enum (`State`, `Action`, `ViewAction`, and any other nested type — a `Route`, a sub-state —
///   recursively down its own tree), skipping the non-state members `Environment`/`Content`/`Input` and
///   the `ViewState` view projection; and (for `strategy: .observationGranular`) `@Tracked` to the
///   tracked `State`/`ViewState`. A user attribute (`@ApplyOptics`/`@Lenses`/`@Prisms`/`@NoOptics`) on a
///   nested type wins. State declared in an *extension* of the feature isn't visible to the macro —
///   annotate that extension with `@ApplyOptics(recursively: true)` directly.
/// - `MemberMacro`          — synthesises `initialState(with:)` (Void seed) when not written, and
///   generates `view(store:environment:) -> some View` (when a `Content` view exists) building the
///   store named by `strategy:` (`ViewStore` / `TrackedViewStore` / `ObservableObjectStore`) from an
///   environment-aware projection. The two Observation stores are iOS-17-gated; Combine is not.
/// - `ExtensionMacro`       — generates the `Feature` conformance when the type has a view (a `Content`,
///   or a hand-written `view`); a view-less feature is a behavior only and gets no `Feature`
///   conformance. The `Feature` conformance is iOS-17-gated for the Observation strategies, ungated for
///   Combine (matching the generated `view()`).
///
/// **Access follows the `enum`'s own modifier** — a `public enum` gets `public` members; a plain `enum`
/// keeps them `internal` — read from the declaration, exactly like `@BoundTo`/`@Tracked`. `ViewState`/
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

    /// Builds `view(store:environment:)`. `strategy:` picks the store (the two Observation stores are
    /// iOS-17-gated, Combine is not). When a `ViewState` struct / `ViewAction` enum exists we project
    /// through the (env-aware) maps; otherwise the store is wrapped as-is, with an unmapped axis in a
    /// mixed feature falling back to identity.
    private static func viewMember(
        access: String,
        node: AttributeSyntax,
        declaration: some DeclGroupSyntax
    ) -> DeclSyntax {
        let storeType: String
        let gated: Bool
        switch strategyName(node) {
        case "observationGranular": (storeType, gated) = ("TrackedViewStore", true)
        case "combineObservable": (storeType, gated) = ("ObservableObjectStore", false)
        default: (storeType, gated) = ("ViewStore", true)
        }
        let availability = gated ? "@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)\n" : ""

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
            source = "store.projection(environment: environment, action: \(actionMap), state: \(stateMap))"
        } else {
            source = "store" // no view layer — wrap the store directly (ViewState == State)
        }
        // The store parameter is `any StoreType<Action, State>` (an existential — a CONCRETE type),
        // not `some StoreType<…>` (a generic parameter). A generic method returning `some View`
        // cannot bind the `ViewFactory.Body` associated type, so the feature couldn't conform to
        // `Feature`; the existential can. Callers are unaffected — a `Store` boxes into it.
        return """
        \(raw: availability)@MainActor \(raw: access)static func view(
            store: any StoreType<Action, State>,
            environment: Environment
        ) -> some View {
            Content(viewStore: \(raw: storeType)(\(raw: source)))
        }
        """
    }

    // MARK: - ExtensionMacro

    /// Generates the protocol conformance. A feature that builds a view — it has a `Content` (the macro
    /// generates `view()`) or a hand-written `view` — conforms to `Feature`; a view-less feature is a
    /// behavior only and conforms to `HasBehavior`. The `Feature` conformance carries the same iOS-17
    /// gate as the generated `view()` for the Observation strategies (ungated for Combine); a witness
    /// gated more narrowly than its requirement wouldn't satisfy it.
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
        // Gated for the Observation strategies (their `view()` is iOS-17), ungated for Combine —
        // matching the generated `view()`'s own availability.
        let gated = strategyName(node) != "combineObservable"
        let availability = gated ? "@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)\n" : ""
        let conformance: DeclSyntax = "\(raw: availability)extension \(raw: type.trimmedDescription): Feature {}"
        return conformance.as(ExtensionDeclSyntax.self).map { [$0] } ?? []
    }

    // MARK: - MemberAttributeMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        let granular = strategyName(node) == "observationGranular"

        // `ViewState` is the view projection, not domain state: `@Tracked` for granular; never optics.
        if let structDecl = member.as(StructDeclSyntax.self), structDecl.name.text == "ViewState" {
            guard granular, !hasAttribute("Tracked", on: structDecl.attributes) else { return [] }
            return ["@Tracked"]
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

        var result: [AttributeSyntax] = []
        // Respect a user-written optics choice — `@ApplyOptics`/`@Lenses`/`@Prisms` (custom options) or
        // `@NoOptics` (opt this type out).
        let userChoseOptics = ["ApplyOptics", "Lenses", "Prisms", "NoOptics"]
            .contains { hasAttribute($0, on: attributes) }
        if !userChoseOptics {
            result.append("@ApplyOptics(recursively: true)")
        }
        // Granular with no distinct `ViewState` struct ⇒ track the domain `State` directly.
        if name == "State",
           granular,
           !hasNestedStruct("ViewState", in: declaration),
           !hasAttribute("Tracked", on: attributes) {
            result.append("@Tracked")
        }
        return result
    }

    // MARK: - Private

    /// The member-access case name of a labeled argument, e.g. `strategy: .observationSimple` → `"observationSimple"`.
    private static func argumentCase(_ label: String, in node: AttributeSyntax) -> String? {
        guard let args = node.arguments?.as(LabeledExprListSyntax.self) else { return nil }
        for arg in args where arg.label?.text == label {
            return arg.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
        }
        return nil
    }

    /// The access modifier the members should carry, read from the attached `enum` — `"public "`,
    /// `"package "`, `""` (internal), etc. Matches `@BoundTo`/`@Tracked`: the declaration's own access
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

    /// The `strategy:` case name; defaults to `"observationSimple"` (coarse `ViewStore`).
    private static func strategyName(_ node: AttributeSyntax) -> String {
        argumentCase("strategy", in: node) ?? "observationSimple"
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
