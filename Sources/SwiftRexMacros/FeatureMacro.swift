import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@Feature(_ role:)` — the single macro for a module entry point or an internal screen.
///
/// - `MemberAttributeMacro` — adds `@Prisms` to nested `Action`, `@Lenses` to nested `State`, and
///   `@ViewModel` to nested `ViewModel`.
/// - `MemberMacro`          — synthesises `initialState(with:)` (Void seed) when not written, and
///   always generates `view(store:environment:) -> some View`, which builds the (reused)
///   `@ViewModel` from an environment-applied projection and hands it to the internal `Content`.
///
/// It generates **no** protocol conformance: `State`/`Action`/`Environment`/`Input` stay whatever
/// access the author declares (public for an entry point), while `ViewModel`/`ViewState`/
/// `ViewAction`/`Content` stay internal and are hidden behind `view()`'s opaque return.
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

        // The erased entry: build the reused `@ViewModel` from an environment-aware projection —
        // both `mapAction` (parse side) and `mapState` (format side) are `Reader<Environment, …>`,
        // applied by the projection — and wrap it in the internal `Content`. The opaque `some View`
        // return hides `Content`/`ViewModel` from other packages.
        members.append(
            """
            @MainActor \(raw: access)static func view(
                store: some StoreType<Action, State>,
                environment: Environment
            ) -> some View {
                Content(viewModel: ViewModel(store: store.projection(environment: environment, action: mapAction, state: mapState)))
            }
            """
        )

        return members
    }

    // MARK: - MemberAttributeMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        if let enumDecl = member.as(EnumDeclSyntax.self), enumDecl.name.text == "Action" {
            guard !hasAttribute("Prisms", on: enumDecl.attributes) else { return [] }
            return ["@Prisms"]
        }
        if let structDecl = member.as(StructDeclSyntax.self), structDecl.name.text == "State" {
            guard !hasAttribute("Lenses", on: structDecl.attributes) else { return [] }
            return ["@Lenses"]
        }
        if let classDecl = member.as(ClassDeclSyntax.self), classDecl.name.text == "ViewModel" {
            guard !hasAttribute("ViewModel", on: classDecl.attributes) else { return [] }
            return ["@ViewModel"]
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

    private static func hasInitialState(in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains {
            $0.decl.as(FunctionDeclSyntax.self)?.name.text == "initialState"
        }
    }
}
