import Foundation

// GenerateLifts — offline codegen for the SwiftRex lift / on matrix.
//
// Emits committed Swift source for the repetitive lift/on overloads across the three layers
// (Reducer / Behavior / Middleware). Run with the SwiftRex source dir as argv[1]:
//
//     swift run GenerateLifts Sources/SwiftRex
//
// CI runs this and fails on any `git diff`, so the committed output can never drift.
// Slice 1 (this file): the Reducer `lift` matrix.

// MARK: - Axes

enum ActionAxis {
    case none, closure, prism, affine, prismKeyPath, affineKeyPath

    /// Does this axis transform the action type (introducing a GlobalAction generic)?
    var transforms: Bool { if case .none = self { false } else { true } }
    var isKeyPath: Bool { self == .prismKeyPath || self == .affineKeyPath }

    /// Parameter declaration(s) for the method signature, one per element.
    var params: [String] {
        switch self {
        case .none: []
        case .closure: ["actionGetter: @escaping @Sendable (GlobalAction) -> ActionType?"]
        case .prism: ["action actionPrism: Prism<GlobalAction, ActionType>"]
        case .affine: ["action actionTraversal: AffineTraversal<GlobalAction, ActionType>"]
        case .prismKeyPath: ["action path: PrismKeyPath<GlobalAction, ActionType>"]
        case .affineKeyPath: ["action path: AffineKeyPath<GlobalAction, ActionType>"]
        }
    }

    /// Generic constraint contributed to the `<...>` clause.
    var generic: String? {
        switch self {
        case .none: nil
        case .prismKeyPath: "GlobalAction: Prismatic & Sendable"
        default: "GlobalAction: Sendable"
        }
    }

    /// The `Prism`/`AffineTraversal` expression a key-path twin delegates through.
    var keyPathOpticExpr: String { self == .prismKeyPath ? "Prism(path)" : "AffineTraversal(path)" }

    /// `guard`-extract line binding `localAction`, for non-delegating action-transforming overloads.
    var extractLine: String? {
        switch self {
        case .none, .prismKeyPath, .affineKeyPath: nil
        case .closure: "guard let localAction = actionGetter(globalAction) else { return .identity }"
        case .prism: "guard let localAction = actionPrism.preview(globalAction) else { return .identity }"
        case .affine: "guard let localAction = actionTraversal.preview(globalAction) else { return .identity }"
        }
    }
}

enum StateAxis {
    case none, closure, writableKeyPath, lens, prism, affine

    var transforms: Bool { if case .none = self { false } else { true } }

    var params: [String] {
        switch self {
        case .none: []
        case .closure: [
            "stateGetter: @escaping @Sendable (GlobalState) -> StateType",
            "stateSetter: @escaping @Sendable (inout GlobalState, StateType) -> Void"
        ]
        case .writableKeyPath: ["state keyPath: WritableKeyPath<GlobalState, StateType>"]
        case .lens: ["state lens: Lens<GlobalState, StateType>"]
        case .prism: ["state statePrism: Prism<GlobalState, StateType>"]
        case .affine: ["state stateTraversal: AffineTraversal<GlobalState, StateType>"]
        }
    }

    var generic: String? { transforms ? "GlobalState: Sendable" : nil }

    /// Wraps `inner` (an `EndoMut<StateType>`) into the result `EndoMut`.
    func apply(_ inner: String) -> String {
        switch self {
        case .none: inner
        case .closure: "Lens(get: stateGetter, setMut: stateSetter).lift(\(inner))"
        case .writableKeyPath: "EndoMut { globalState in \(inner)(&globalState[keyPath: keyPath]) }"
        case .lens: "lens.lift(\(inner))"
        case .prism: "statePrism.lift(\(inner))"
        case .affine: "stateTraversal.lift(\(inner))"
        }
    }

    /// The `, label: value` fragment a key-path twin forwards (empty for `.none`).
    var forwardArg: String {
        switch self {
        case .none: ""
        case .closure: ", stateGetter: stateGetter, stateSetter: stateSetter"
        case .writableKeyPath: ", state: keyPath"
        case .lens: ", state: lens"
        case .prism: ", state: statePrism"
        case .affine: ", state: stateTraversal"
        }
    }
}

// MARK: - Emit one Reducer.lift overload

func emitReducerLift(action: ActionAxis, state: StateAxis) -> String {
    let resultAction = action.transforms ? "GlobalAction" : "ActionType"
    let resultState = state.transforms ? "GlobalState" : "StateType"
    let generics = [action.generic, state.generic].compactMap { $0 }
    let genericClause = generics.isEmpty ? "" : "<\(generics.joined(separator: ", "))>"
    let params = action.params + state.params

    var lines: [String] = []
    lines.append("    /// Lifts \(describe(action: action, state: state)).")
    lines.append("    public func lift\(genericClause)(")
    for (i, param) in params.enumerated() {
        lines.append("        \(param)\(i == params.count - 1 ? "" : ",")")
    }
    lines.append("    ) -> Reducer<\(resultAction), \(resultState)> {")

    if action.isKeyPath {
        lines.append("        lift(action: \(action.keyPathOpticExpr)\(state.forwardArg))")
    } else if action.transforms {
        lines.append("        .reduce { globalAction in")
        if let extract = action.extractLine { lines.append("            \(extract)") }
        lines.append("            return \(state.apply("self.reduce(localAction)"))")
        lines.append("        }")
    } else {
        lines.append("        .reduce { action in \(state.apply("self.reduce(action)")) }")
    }

    lines.append("    }")
    return lines.joined(separator: "\n")
}

func describe(action: ActionAxis, state: StateAxis) -> String {
    let a: String? = switch action {
    case .none: nil
    case .closure: "the action axis via a getter closure"
    case .prism: "the action axis via a `Prism`"
    case .affine: "the action axis via an `AffineTraversal`"
    case .prismKeyPath: "the action axis via a `PrismKeyPath`"
    case .affineKeyPath: "the action axis via an `AffineKeyPath`"
    }
    let s: String? = switch state {
    case .none: nil
    case .closure: "the state axis via getter/setter closures"
    case .writableKeyPath: "the state axis via a `WritableKeyPath`"
    case .lens: "the state axis via a `Lens`"
    case .prism: "the state axis via a `Prism`"
    case .affine: "the state axis via an `AffineTraversal`"
    }
    return [a, s].compactMap { $0 }.joined(separator: ", and ")
}

// MARK: - The Reducer lift matrix (existing 17 + 10 PrismKeyPath/AffineKeyPath twins)

let reducerCombos: [(ActionAxis, StateAxis)] = [
    (.closure, .closure), (.closure, .none), (.none, .closure),
    (.none, .writableKeyPath), (.none, .lens), (.none, .prism), (.none, .affine),
    (.prism, .none), (.prism, .writableKeyPath), (.prism, .lens), (.prism, .prism), (.prism, .affine),
    (.affine, .none), (.affine, .writableKeyPath), (.affine, .lens), (.affine, .prism), (.affine, .affine),
    (.prismKeyPath, .none), (.prismKeyPath, .writableKeyPath), (.prismKeyPath, .lens),
    (.prismKeyPath, .prism), (.prismKeyPath, .affine),
    (.affineKeyPath, .none), (.affineKeyPath, .writableKeyPath), (.affineKeyPath, .lens),
    (.affineKeyPath, .prism), (.affineKeyPath, .affine)
]

func generateReducerLift() -> String {
    let overloads = reducerCombos.map { emitReducerLift(action: $0.0, state: $0.1) }.joined(separator: "\n\n")
    return """
    // Generated by GenerateLifts — do not edit. Run `swift run GenerateLifts Sources/SwiftRex`.

    import CoreFP
    import DataStructure

    // Lifts a `Reducer<ActionType, StateType>` into a parent action/state, across every
    // combination of action and state optics (closure, Prism, AffineTraversal, Lens,
    // WritableKeyPath, PrismKeyPath, AffineKeyPath). The reducer is a no-op for unmatched
    // actions or absent state foci.
    extension Reducer {
    \(overloads)
    }
    """
}

// MARK: - Middleware PrismKeyPath action twins (the gap — Behavior already has these)
//
// Additive: `PrismKeyPath` action spellings of the Middleware lift overloads whose Prism-action
// versions live in Middleware+Transforms. Each recovers the prism via `Prism(path)` and delegates.
// (Behavior's equivalents are hand-written in Behavior+Transforms; only Middleware lacked them.)

func emitMiddlewarePrismTwin(stateParam: String, forward: String, stateDoc: String) -> String {
    [
        "    /// Lifts all three axes — `PrismKeyPath` action, \(stateDoc) state, closure environment.",
        "    public func lift<GA: Prismatic & Sendable, GS: Sendable, GE: Sendable>(",
        "        action path: PrismKeyPath<GA, Action>,",
        "        \(stateParam),",
        "        environment g: @escaping @Sendable (GE) -> Environment",
        "    ) -> Middleware<GA, GS, GE> {",
        "        lift(action: Prism(path), state: \(forward), environment: g)",
        "    }"
    ].joined(separator: "\n")
}

func generateMiddlewarePrismKeyPath() -> String {
    let liftActionTwin = [
        "    /// Lifts the action axis via a `PrismKeyPath`.",
        "    public func liftAction<GlobalAction: Prismatic & Sendable>(",
        "        _ path: PrismKeyPath<GlobalAction, Action>",
        "    ) -> Middleware<GlobalAction, State, Environment> {",
        "        liftAction(Prism(path))",
        "    }"
    ].joined(separator: "\n")

    let combinedTwins = [
        emitMiddlewarePrismTwin(stateParam: "state f: @escaping @Sendable (GS) -> State", forward: "f", stateDoc: "closure"),
        emitMiddlewarePrismTwin(stateParam: "state lens: Lens<GS, State>", forward: "lens", stateDoc: "`Lens`"),
        emitMiddlewarePrismTwin(stateParam: "state statePrism: Prism<GS, State>", forward: "statePrism", stateDoc: "`Prism`"),
        emitMiddlewarePrismTwin(stateParam: "state traversal: AffineTraversal<GS, State>", forward: "traversal", stateDoc: "`AffineTraversal`")
    ].joined(separator: "\n\n")

    return """
    // Generated by GenerateLifts — do not edit. Run `swift run GenerateLifts Sources/SwiftRex`.

    import CoreFP
    import DataStructure

    // `PrismKeyPath` action spellings of the Middleware lift overloads. The Prism-action
    // versions live in Middleware+Transforms; these recover the prism via `Prism(path)`.
    extension Middleware {
    \(liftActionTwin)

    \(combinedTwins)
    }
    """
}

// MARK: - Entry point

let baseDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Sources/SwiftRex"

func write(_ contents: String, to relativePath: String) {
    let url = URL(fileURLWithPath: baseDir).appendingPathComponent(relativePath)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? (contents + "\n").write(to: url, atomically: true, encoding: .utf8)
    print("wrote \(url.path)")
}

write(generateReducerLift(), to: "__Generated__/Reducer+Lift.swift")
write(generateMiddlewarePrismKeyPath(), to: "__Generated__/Middleware+LiftPrismKeyPath.swift")
