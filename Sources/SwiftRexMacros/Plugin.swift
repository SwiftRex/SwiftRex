import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftRexMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        ViewModelMacro.self,
        FeatureMacro.self,
        BoundToMacro.self
    ]
}
