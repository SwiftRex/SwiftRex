import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@Feature(_ role:)` — the single macro for a module entry point or an internal screen.
///
/// - `MemberAttributeMacro` — adds `@Prisms` to nested `Action` and `ViewAction`, and `@Lenses` to
///   nested `State`.
/// - `MemberMacro`          — synthesises `initialState(with:)` (Void seed) when not written, and
///   generates `view(store:environment:) -> some View` (when a `Content` view exists) building the
///   view store from an environment-aware projection: a coarse `ViewStore`, or a field-level
///   `TrackedViewStore` when the nested `ViewState` is `@Tracked`.
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
        // The view store is picked by observation strategy: `@Tracked` on the nested `ViewState`
        // ⇒ field-level `TrackedViewStore`, otherwise the coarse `ViewStore`. The opaque `some View`
        // return hides `Content`/`ViewState`/`ViewAction` from other packages.
        if hasNestedType("Content", in: declaration) {
            let store = hasTrackedViewState(in: declaration) ? "TrackedViewStore" : "ViewStore"
            members.append(
                """
                @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
                @MainActor \(raw: access)static func view(
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
        return []
    }

    // MARK: - Private

    /// Whether `@Feature(.publicEntryPoint)` was requested. Defaults to `true` (public) when the
    /// role argument is absent or unrecognised.
    private static func isPublicEntryPoint(_ node: AttributeSyntax) -> Bool {
        guard let args = node.arguments?.as(LabeledExprListSyntax.self),
              let member = args.first?.expression.as(MemberAccessExprSyntax.self)
        else { return true }
        return member.declName.baseName.text != "internalScreen"
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

    /// Whether the nested `ViewState` struct is annotated `@Tracked` — the syntactic signal that
    /// the generated `view()` should build a field-level `TrackedViewStore` rather than `ViewStore`.
    private static func hasTrackedViewState(in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains { member in
            guard let structDecl = member.decl.as(StructDeclSyntax.self),
                  structDecl.name.text == "ViewState" else { return false }
            return hasAttribute("Tracked", on: structDecl.attributes)
        }
    }

    private static func hasInitialState(in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains {
            $0.decl.as(FunctionDeclSyntax.self)?.name.text == "initialState"
        }
    }
}
