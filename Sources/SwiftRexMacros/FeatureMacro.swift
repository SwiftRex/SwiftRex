import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@Feature`:
/// - `ExtensionMacro`       — adds `Feature` protocol conformance
/// - `MemberAttributeMacro` — adds `@Prisms` to nested `Action` enum,
///                            `@Lenses` to nested `State` struct, and
///                            `@ViewModel` to nested `ViewModel` class.
/// - `MemberMacro`          — synthesizes `static func initialState() -> State { .init() }`
///                            when the feature has a nested `State` and hasn't written its own.
public struct FeatureMacro: ExtensionMacro, MemberAttributeMacro, MemberMacro {
    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // `initialState()` defaults to `State.init()` — the common case where every
        // `State` property has a default. Only synthesize when the feature has a nested
        // `State` type and hasn't supplied its own `initialState()`; a `State` without an
        // empty initializer must declare `initialState()` explicitly.
        guard declaration.is(EnumDeclSyntax.self),
              hasNestedType("State", in: declaration),
              !hasInitialState(in: declaration)
        else { return [] }
        return ["static func initialState() -> State { .init() }"]
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(EnumDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: FeatureDiagnostic.mustBeEnum))
            return []
        }
        return [try ExtensionDeclSyntax("extension \(type): Feature {}")]
    }

    // MARK: - MemberAttributeMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Add @Prisms (prism namespace + cases) to nested `enum Action`
        if let enumDecl = member.as(EnumDeclSyntax.self), enumDecl.name.text == "Action" {
            guard !hasAttribute("Prisms", on: enumDecl.attributes) else { return [] }
            return ["@Prisms"]
        }
        // Add @Lenses to nested `struct State`
        if let structDecl = member.as(StructDeclSyntax.self), structDecl.name.text == "State" {
            guard !hasAttribute("Lenses", on: structDecl.attributes) else { return [] }
            return ["@Lenses"]
        }
        // Add @ViewModel to nested `class ViewModel`
        if let classDecl = member.as(ClassDeclSyntax.self), classDecl.name.text == "ViewModel" {
            guard !hasAttribute("ViewModel", on: classDecl.attributes) else { return [] }
            return ["@ViewModel"]
        }
        return []
    }

    // MARK: - Private

    private static func hasAttribute(_ name: String, on attributes: AttributeListSyntax) -> Bool {
        attributes.contains {
            $0.as(AttributeSyntax.self)?
                .attributeName
                .as(IdentifierTypeSyntax.self)?
                .name.text == name
        }
    }

    /// Whether the feature declares a nested type (struct/enum/class/actor/typealias) with `name`.
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

    /// Whether the feature already declares an `initialState` function (user-supplied override).
    private static func hasInitialState(in declaration: some DeclGroupSyntax) -> Bool {
        declaration.memberBlock.members.contains {
            $0.decl.as(FunctionDeclSyntax.self)?.name.text == "initialState"
        }
    }
}
