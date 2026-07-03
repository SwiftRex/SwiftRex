import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Implements `@Tracked` — generates an `@Observable` reference mirror (`Tracked`) for a value
/// `ViewState` struct, plus a `TrackedState` conformance.
///
/// The mirror carries the same stored properties as `@Observable`-tracked computed pairs, an
/// `init(_:)` seed, and an in-place `update(from:)` that touches only changed fields — the
/// field-level observation codegen (`ObservationRegistrar` + per-field computed pairs), minus any
/// store/dispatch wiring (that lives in `TrackedViewStore`), homed on a nested class.
public struct TrackedMacro: MemberMacro, ExtensionMacro {
    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: TrackedDiagnostic.mustBeStruct))
            return []
        }

        let fields = storedFields(of: structDecl)
        guard !fields.isEmpty else {
            context.diagnose(Diagnostic(node: Syntax(structDecl.name), message: TrackedDiagnostic.emptyState))
            return []
        }

        let access = accessModifier(from: structDecl.modifiers)
        let source = structDecl.name.text
        return [buildTrackedClass(access: access, source: source, fields: fields)]
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
        return [try ExtensionDeclSyntax("extension \(type): TrackedState {}")]
    }

    // MARK: - Codegen

    private static func buildTrackedClass(
        access: String,
        source: String,
        fields: [(name: String, type: TypeSyntax)]
    ) -> DeclSyntax {
        let fieldMembers = fields.map { name, type in
            """
                \(access)var \(name): \(type) {
                    get {
                        _$observationRegistrar.access(self, keyPath: \\.\(name))
                        return _\(name)
                    }
                    set {
                        _$observationRegistrar.withMutation(of: self, keyPath: \\.\(name)) {
                            _\(name) = newValue
                        }
                    }
                }
                @ObservationIgnored private var _\(name): \(type)
            """
        }.joined(separator: "\n")

        let seeds = fields.map { "        _\($0.name) = source.\($0.name)" }.joined(separator: "\n")
        let updates = fields
            .map { "        if \($0.name) != source.\($0.name) { \($0.name) = source.\($0.name) }" }
            .joined(separator: "\n")

        return """
            // @unchecked Sendable: mutated only on the main actor via TrackedViewStore.
            \(raw: access)final class Tracked: Observation.Observable, TrackedMirror, @unchecked Sendable {
                @ObservationIgnored private let _$observationRegistrar = ObservationRegistrar()

                \(raw: access)nonisolated func access<_Member>(keyPath: KeyPath<Tracked, _Member>) {
                    _$observationRegistrar.access(self, keyPath: keyPath)
                }
                \(raw: access)nonisolated func withMutation<_Member, _Result>(
                    keyPath: KeyPath<Tracked, _Member>,
                    _ mutation: () throws -> _Result
                ) rethrows -> _Result {
                    try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
                }

            \(raw: fieldMembers)

                @MainActor \(raw: access)init(_ source: \(raw: source)) {
            \(raw: seeds)
                }

                @MainActor \(raw: access)func update(from source: \(raw: source)) {
            \(raw: updates)
                }
            }
            """
    }

    // MARK: - Private helpers

    private static func storedFields(of structDecl: StructDeclSyntax) -> [(name: String, type: TypeSyntax)] {
        structDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { !$0.modifiers.contains(where: { $0.name.text == "static" }) }
            .flatMap { varDecl -> [(String, TypeSyntax)] in
                varDecl.bindings.compactMap { binding in
                    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                          let annotation = binding.typeAnnotation else { return nil }
                    return (pattern.identifier.text, annotation.type.trimmed)
                }
            }
    }

    private static func accessModifier(from modifiers: DeclModifierListSyntax) -> String {
        modifiers
            .first(where: {
                switch $0.name.tokenKind {
                case .keyword(.public), .keyword(.package), .keyword(.internal),
                     .keyword(.fileprivate), .keyword(.open):
                    true
                default:
                    false
                }
            })
            .map { "\($0.name.text) " } ?? ""
    }
}
