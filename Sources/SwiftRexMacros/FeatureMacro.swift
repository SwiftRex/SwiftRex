import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@Feature`:
/// - `ExtensionMacro`     — adds `Feature` protocol conformance
/// - `MemberAttributeMacro` — adds `@Prisms` to nested `Action` enum,
///                            adds `@Lenses` to nested `State` struct
public struct FeatureMacro: ExtensionMacro, MemberAttributeMacro {
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
        // Add @Prisms to nested `enum Action`
        if let enumDecl = member.as(EnumDeclSyntax.self), enumDecl.name.text == "Action" {
            guard !hasAttribute("Prisms", on: enumDecl.attributes) else { return [] }
            return [AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("Prisms")))]
        }
        // Add @Lenses to nested `struct State`
        if let structDecl = member.as(StructDeclSyntax.self), structDecl.name.text == "State" {
            guard !hasAttribute("Lenses", on: structDecl.attributes) else { return [] }
            return [AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("Lenses")))]
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
}
