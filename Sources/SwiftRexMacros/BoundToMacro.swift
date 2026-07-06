// SPDX-License-Identifier: Apache-2.0

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@BoundTo(Feature.self, strategy:)` — injects the view's `viewStore` stored property
/// with the observation wrapper that matches the feature's `ViewStrategy`.
///
/// The strategy can't be read off the feature (a macro sees only its own attached declaration and
/// arguments, never another type's attributes), so it's passed here too; the compiler enforces
/// consistency because `Feature.view()` builds a store of exactly this type.
///
/// | `strategy:` | injected property |
/// | --- | --- |
/// | `.observationSimple` | `let viewStore: ViewStore<F.ViewState, F.ViewAction>` |
/// | `.observationGranular` | `let viewStore: TrackedViewStore<F.ViewState, F.ViewAction>` |
/// | `.combineObservable` | `@ObservedObject var viewStore: ObservableObjectStore<F.ViewAction, F.ViewState>` |
///
/// The view reads `viewStore.state.field` / `viewStore.dispatch(_:)` identically in all three; the
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

        let strategy = args
            .first(where: { $0.label?.text == "strategy" })?
            .expression.as(MemberAccessExprSyntax.self)?
            .declName.baseName.text ?? "observationSimple"

        let access = accessModifier(from: structDecl.modifiers)

        let property: DeclSyntax = switch strategy {
        case "observationGranular":
            "\(raw: access)let viewStore: TrackedViewStore<\(raw: feature).ViewState, \(raw: feature).ViewAction>"
        case "combineObservable":
            "\(raw: access)@ObservedObject var viewStore: ObservableObjectStore<\(raw: feature).ViewAction, \(raw: feature).ViewState>"
        default:
            "\(raw: access)let viewStore: ViewStore<\(raw: feature).ViewState, \(raw: feature).ViewAction>"
        }
        return [property]
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
