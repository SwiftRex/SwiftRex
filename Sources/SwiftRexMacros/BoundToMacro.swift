import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@BoundTo(FeatureType.self)`:
/// - `MemberMacro`    — generates `typealias VM`, `let viewModel`, and `init(viewModel:)`
/// - `ExtensionMacro` — adds `HasViewModel` protocol conformance
public struct BoundToMacro: MemberMacro, ExtensionMacro {
    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: BoundToDiagnostic.mustBeStruct))
            return []
        }
        guard let featureName = extractFeatureName(from: node) else {
            context.diagnose(Diagnostic(node: node, message: BoundToDiagnostic.missingFeatureType))
            return []
        }

        let access = accessModifier(from: declaration)

        return [
            "\(raw: access)typealias VM = \(raw: featureName).ViewModel",
            "\(raw: access)let viewModel: \(raw: featureName).ViewModel",
            """
            \(raw: access)init(viewModel: \(raw: featureName).ViewModel) {
                self.viewModel = viewModel
            }
            """
        ]
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else { return [] }
        return [try ExtensionDeclSyntax("extension \(type): HasViewModel {}")]
    }

    // MARK: - Private

    /// Extracts `"MoviesFeature"` (or `"App.MoviesFeature"`) from `@BoundTo(MoviesFeature.self)`.
    private static func extractFeatureName(from node: AttributeSyntax) -> String? {
        guard
            let args = node.arguments?.as(LabeledExprListSyntax.self),
            let first = args.first,
            let memberAccess = first.expression.as(MemberAccessExprSyntax.self),
            memberAccess.declName.baseName.text == "self",
            let base = memberAccess.base
        else { return nil }
        return "\(base.trimmed)"
    }

    private static func accessModifier(from declaration: some DeclGroupSyntax) -> String {
        let modifiers = declaration.as(StructDeclSyntax.self)?.modifiers
        return modifiers?.first(where: {
            switch $0.name.tokenKind {
            case .keyword(.public), .keyword(.package), .keyword(.internal), .keyword(.fileprivate):
                true
            default:
                false
            }
        }).map { "\($0.name.text) " } ?? ""
    }
}
