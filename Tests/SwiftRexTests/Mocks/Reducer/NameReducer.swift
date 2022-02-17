import SwiftRex

let createNameReducer: () -> Reducer<AppAction, TestState> = {
    .reduce { action, state in
        switch action {
        case .foo: state.name = "foo"
        case .bar(.alpha): state.name = "alpha"
        case .bar(.bravo): state.name = "bravo"
        case .bar(.charlie): state.name = "charlie"
        case .bar(.delta): state.name = "delta"
        case .bar(.echo): state.name = "echo"
        case .scoped: state.name = "scoped"
        }
    }
}
