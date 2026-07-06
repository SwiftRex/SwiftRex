// SPDX-License-Identifier: Apache-2.0

import SwiftDiagnostics

enum FeatureDiagnostic: DiagnosticMessage {
    case mustBeEnum

    var message: String {
        switch self {
        case .mustBeEnum:
            "@Feature can only be applied to an enum"
        }
    }

    var diagnosticID: MessageID { MessageID(domain: "SwiftRexMacros", id: "\(self)") }
    var severity: DiagnosticSeverity { .error }
}

enum BoundToDiagnostic: DiagnosticMessage {
    case mustBeStruct
    case missingFeatureType

    var message: String {
        switch self {
        case .mustBeStruct:
            "@BoundTo can only be applied to a struct"
        case .missingFeatureType:
            "@BoundTo requires a Feature type argument — e.g. @BoundTo(MoviesFeature.self, strategy: .observationSimple)"
        }
    }

    var diagnosticID: MessageID { MessageID(domain: "SwiftRexMacros", id: "\(self)") }
    var severity: DiagnosticSeverity { .error }
}

enum TrackedDiagnostic: DiagnosticMessage {
    case mustBeStruct
    case emptyState

    var message: String {
        switch self {
        case .mustBeStruct:
            "@Tracked can only be applied to a struct"
        case .emptyState:
            "the @Tracked struct must have at least one stored property (with an explicit type) " +
                "for the mirror to generate tracked fields"
        }
    }

    var diagnosticID: MessageID { MessageID(domain: "SwiftRexMacros", id: "\(self)") }
    var severity: DiagnosticSeverity { .error }
}
