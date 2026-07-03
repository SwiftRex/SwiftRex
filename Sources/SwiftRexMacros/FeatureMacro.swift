import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@Feature(type:strategy:)` — the module-entry/internal-screen macro.
///
/// - `MemberAttributeMacro` — adds `@Prisms` to nested `Action`/`ViewAction`, `@Lenses` to nested
///   `State`, and (for `strategy: .observationGranular`) `@Tracked` to nested `ViewState`.
/// - `MemberMacro`          — synthesises `initialState(with:)` (Void seed) when not written, and
///   generates `view(store:environment:) -> some View` (when a `Content` view exists) building the
///   store named by `strategy:` (`ViewStore` / `TrackedViewStore` / `ObservableObjectStore`) from an
///   environment-aware projection. The two Observation stores are iOS-17-gated; Combine is not.
///
/// It generates **no** protocol conformance: `State`/`Action`/`Environment`/`Input` stay whatever
/// access the author declares (public for an entry point), while `ViewState`/`ViewAction`/`Content`
/// stay internal and are hidden behind `view()`'s opaque return.
public struct FeatureMacro: MemberAttributeMacro, MemberMacro {
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

        let access = isPublicEntryPoint(node) ? "public " : ""
        var members: [DeclSyntax] = []

        // `initialState(with:)` defaults to `State.init()` for the common Void-seed case. Only
        // synthesise when there is a nested `State`, no custom `Input` seed, and no user override.
        if hasNestedType("State", in: declaration),
           !hasNestedType("Input", in: declaration),
           !hasInitialState(in: declaration) {
            members.append("\(raw: access)static func initialState(with _: Void) -> State { .init() }")
        }

        // The erased entry — generated only when the feature has a `Content` view. Both `mapAction`
        // (parse) and `mapState` (format) are `Reader<Environment, …>`, applied by the projection.
        // `strategy:` picks the store; the two Observation stores are iOS-17-gated, the Combine one
        // is not. The opaque `some View` return hides `Content`/`ViewState`/`ViewAction`.
        if hasNestedType("Content", in: declaration) {
            let store: String
            let gated: Bool
            switch strategyName(node) {
            case "observationGranular": (store, gated) = ("TrackedViewStore", true)
            case "combineObservable":   (store, gated) = ("ObservableObjectStore", false)
            default:                    (store, gated) = ("ViewStore", true)
            }
            let availability = gated ? "@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)\n" : ""
            members.append(
                """
                \(raw: availability)@MainActor \(raw: access)static func view(
                    store: some StoreType<Action, State>,
                    environment: Environment
                ) -> some View {
                    Content(viewStore: \(raw: store)(store.projection(environment: environment, action: mapAction, state: mapState)))
                }
                """
            )
        }

        return members
    }

    // MARK: - MemberAttributeMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        if let enumDecl = member.as(EnumDeclSyntax.self),
           enumDecl.name.text == "Action" || enumDecl.name.text == "ViewAction" {
            guard !hasAttribute("Prisms", on: enumDecl.attributes) else { return [] }
            return ["@Prisms"]
        }
        if let structDecl = member.as(StructDeclSyntax.self), structDecl.name.text == "State" {
            guard !hasAttribute("Lenses", on: structDecl.attributes) else { return [] }
            return ["@Lenses"]
        }
        // `.observationGranular` attaches `@Tracked` to the ViewState automatically.
        if let structDecl = member.as(StructDeclSyntax.self), structDecl.name.text == "ViewState" {
            guard strategyName(node) == "observationGranular",
                  !hasAttribute("Tracked", on: structDecl.attributes) else { return [] }
            return ["@Tracked"]
        }
        return []
    }

    // MARK: - Private

    /// The member-access case name of a labeled argument, e.g. `type: .moduleEntryPoint` → `"moduleEntryPoint"`.
    private static func argumentCase(_ label: String, in node: AttributeSyntax) -> String? {
        guard let args = node.arguments?.as(LabeledExprListSyntax.self) else { return nil }
        for arg in args where arg.label?.text == label {
            return arg.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
        }
        return nil
    }

    /// Whether `type: .moduleEntryPoint`. Defaults to `true` (public) when absent/unrecognised.
    private static func isPublicEntryPoint(_ node: AttributeSyntax) -> Bool {
        argumentCase("type", in: node) != "internalOnly"
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

    private static func hasInitialState(in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains {
            $0.decl.as(FunctionDeclSyntax.self)?.name.text == "initialState"
        }
    }
}
