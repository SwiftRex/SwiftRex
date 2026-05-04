/// Identifies a single element within a collection and carries the action to apply to it.
///
/// The call site — typically a view — only knows which element it's acting on (its `id`) and
/// what to do (`action`). Where that collection lives inside the global state is a wiring
/// concern that belongs in `liftCollection`, not at the dispatch site:
///
/// ```swift
/// // View — knows the id and the action, nothing else:
/// store.send(.updateTodo(ElementAction(todo.id, action: .toggleDone)))
/// store.send(.expandSection(ElementAction(2, action: .expand)))
/// store.send(.updateConfig(ElementAction("featureX", action: .toggle)))
///
/// // Reducer wiring — knows where each collection lives:
/// todoReducer.liftCollection(action: \AppAction.updateTodo, stateCollection: \AppState.todos)
/// sectionReducer.liftCollection(action: \AppAction.expandSection, stateCollection: \AppState.sections)
/// configReducer.liftCollection(action: \AppAction.updateConfig, stateDictionary: \AppState.configs)
/// ```
public struct ElementAction<ID, SubAction> {
    public let id: ID
    public let action: SubAction

    public init(_ id: ID, action: SubAction) {
        self.id = id
        self.action = action
    }
}

extension ElementAction: Sendable where ID: Sendable, SubAction: Sendable {}
extension ElementAction: Equatable where ID: Equatable, SubAction: Equatable {}
