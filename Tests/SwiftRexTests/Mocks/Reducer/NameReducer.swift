import SwiftRex

let createNameReducer: () -> Reducer<AppAction, TestState> = {
    .init { action, state in
        switch action {
        case .foo: return .init(value: state.value, name: "foo")
        case .bar(.alpha): return .init(value: state.value, name: "alpha")
        case .bar(.bravo): return .init(value: state.value, name: "bravo")
        case .bar(.charlie): return .init(value: state.value, name: "charlie")
        case .bar(.delta): return .init(value: state.value, name: "delta")
        case .bar(.echo): return .init(value: state.value, name: "echo")
        }
    }
}
