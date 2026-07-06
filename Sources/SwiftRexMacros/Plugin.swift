// SPDX-License-Identifier: Apache-2.0

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftRexMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        FeatureMacro.self,
        TrackedMacro.self,
        BoundToMacro.self
    ]
}
