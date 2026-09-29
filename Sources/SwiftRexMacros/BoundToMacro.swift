// SPDX-License-Identifier: Apache-2.0

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@BoundTo(Feature.self)` — injects the view's `viewStore` stored property:
/// `let viewStore: ViewStore<F.ViewAction, F.ViewState>`.
///
/// A `ViewStore` is a receiver that works under every `ViewStrategy` (it carries its own Combine
/// subscription), so the strategy — chosen once, on `@Feature` — never has to be repeated here. The
/// struct's synthesised memberwise `init(viewStore:)` receives the store from `Feature.view()`.
public struct BoundToMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: BoundToDiagnostic.mustBeStruct))
            return []
        }
        guard let args = node.arguments?.as(LabeledExprListSyntax.self),
              let featureExpr = args.first?.expression.as(MemberAccessExprSyntax.self),
              featureExpr.declName.baseName.text == "self",
              let feature = featureExpr.base?.trimmedDescription else {
            context.diagnose(Diagnostic(node: node, message: BoundToDiagnostic.missingFeatureType))
            return []
        }

        let access = accessModifier(from: structDecl.modifiers)

        return ["\(raw: access)let viewStore: ViewStore<\(raw: feature).ViewAction, \(raw: feature).ViewState>"]
    }

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
}
