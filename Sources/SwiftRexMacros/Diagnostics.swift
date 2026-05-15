import SwiftDiagnostics

enum ViewModelDiagnostic: DiagnosticMessage {
    case mustBeClass
    case noTypealias(name: String)
    case missingViewState
    case missingViewAction
    case emptyViewState

    var message: String {
        switch self {
        case .mustBeClass:
            "@ViewModel can only be applied to a class"
        case .noTypealias(let name):
            "\(name) must be declared inline as a struct or enum — " +
            "@ViewModel inspects its stored properties at compile time and cannot follow a typealias"
        case .missingViewState:
            "@ViewModel requires a nested 'struct ViewState: Equatable' declaration"
        case .missingViewAction:
            "@ViewModel requires a nested 'enum ViewAction' declaration"
        case .emptyViewState:
            "ViewState must have at least one stored property for @ViewModel to generate tracked fields"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SwiftRexViewModelMacros", id: "\(self)")
    }

    var severity: DiagnosticSeverity { .error }
}
