import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct ViewModelMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: ViewModelDiagnostic.mustBeClass))
            return []
        }

        let members = classDecl.memberBlock.members

        // Enforce no typealias for ViewState or ViewAction
        for member in members {
            if let alias = member.decl.as(TypeAliasDeclSyntax.self) {
                let name = alias.name.text
                if name == "ViewState" || name == "ViewAction" {
                    context.diagnose(Diagnostic(
                        node: Syntax(alias.name),
                        message: ViewModelDiagnostic.noTypealias(name: name)
                    ))
                }
            }
        }

        // Find ViewState struct
        guard let viewStateDecl = members
            .compactMap({ $0.decl.as(StructDeclSyntax.self) })
            .first(where: { $0.name.text == "ViewState" }) else {
            context.diagnose(Diagnostic(node: node, message: ViewModelDiagnostic.missingViewState))
            return []
        }

        // Find ViewAction enum
        guard members
            .compactMap({ $0.decl.as(EnumDeclSyntax.self) })
            .contains(where: { $0.name.text == "ViewAction" }) else {
            context.diagnose(Diagnostic(node: node, message: ViewModelDiagnostic.missingViewAction))
            return []
        }

        // Extract stored properties from ViewState
        let fields: [(name: String, type: TypeSyntax)] = viewStateDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { !$0.modifiers.contains(where: { $0.name.text == "static" }) }
            .flatMap { varDecl -> [(String, TypeSyntax)] in
                varDecl.bindings.compactMap { binding in
                    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                          let annotation = binding.typeAnnotation else { return nil }
                    return (pattern.identifier.text, annotation.type.trimmed)
                }
            }

        guard !fields.isEmpty else {
            context.diagnose(Diagnostic(
                node: Syntax(viewStateDecl.name),
                message: ViewModelDiagnostic.emptyViewState
            ))
            return []
        }

        // Match the class's access level for generated public API
        let access = classDecl.modifiers
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

        let className = classDecl.name.text
        var result: [DeclSyntax] = []

        // Observation infrastructure
        result += [
            "@ObservationIgnored private let _$observationRegistrar = ObservationRegistrar()",
            "@ObservationIgnored private var _dispatch: @MainActor @Sendable (ViewAction, ActionSource) -> Void = { _, _ in }",
            "@ObservationIgnored private var _token: SubscriptionToken?"
        ]

        // access(keyPath:) and withMutation(keyPath:mutation:) required by Observable
        result.append(
            """
            \(raw: access)nonisolated func access<_Member>(keyPath: KeyPath<\(raw: className), _Member>) {
                _$observationRegistrar.access(self, keyPath: keyPath)
            }
            """
        )
        result.append(
            """
            \(raw: access)nonisolated func withMutation<_Member, _Result>(
                keyPath: KeyPath<\(raw: className), _Member>,
                _ mutation: () throws -> _Result
            ) rethrows -> _Result {
                try _$observationRegistrar.withMutation(self, keyPath: keyPath, mutation)
            }
            """
        )

        // Per-field: computed property with tracking + private backing store
        for (name, type) in fields {
            result.append(
                """
                \(raw: access)var \(raw: name): \(type) {
                    get {
                        _$observationRegistrar.access(self, keyPath: \\.\(raw: name))
                        return _\(raw: name)
                    }
                    set {
                        _$observationRegistrar.withMutation(self, keyPath: \\.\(raw: name)) {
                            _\(raw: name) = newValue
                        }
                    }
                }
                """
            )
            result.append("@ObservationIgnored private var _\(raw: name): \(type)")
        }

        // Synthesized init
        let seeds = fields
            .map { "        _\($0.name) = initial.\($0.name)" }
            .joined(separator: "\n")
        let updates = fields
            .map { "            if self.\($0.name) != new.\($0.name) { self.\($0.name) = new.\($0.name) }" }
            .joined(separator: "\n")

        result.append(
            """
            \(raw: access)init(store: some StoreType<ViewAction, ViewState>) {
                let initial = store.state
            \(raw: seeds)
                _dispatch = store.dispatch
                _token = store.observe(didChange: { [weak self] in
                    guard let self else { return }
                    let new = store.state
            \(raw: updates)
                })
            }
            """
        )

        // Dispatch forwarding
        result.append(
            """
            \(raw: access)func dispatch(
                _ action: ViewAction,
                file: String = #file,
                function: String = #function,
                line: UInt = #line
            ) {
                _dispatch(action, ActionSource(file: file, function: function, line: line))
            }
            """
        )

        return result
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(ClassDeclSyntax.self) else { return [] }
        return [try ExtensionDeclSyntax("extension \(type): Observable, ViewModel {}")]
    }
}
