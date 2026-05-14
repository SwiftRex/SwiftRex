/// Pairs an element identifier with a sub-action, enabling ``StoreProjection`` to focus on
/// a single element inside a collection without the view knowing where that collection lives.
///
/// `ElementAction` separates two concerns:
///
/// - **The view** only knows *which* element it's acting on (its `id`) and *what* to do
///   (`action`). It does not know whether the element lives in an array, dictionary, or
///   optional inside the global state.
/// - **The wiring layer** (the `liftCollection`/`projection` call) knows where the collection
///   lives and how to map an `ElementAction` into the global action type.
///
/// ```swift
/// // View — knows the id and the local action, nothing else
/// store.dispatch(.updateTodo(ElementAction(todo.id, action: .toggleDone)))
/// store.dispatch(.expandSection(ElementAction(2,       action: .expand)))
/// store.dispatch(.updateConfig(ElementAction("darkMode", action: .toggle)))
///
/// // Reducer wiring — knows where each collection lives
/// todoReducer.liftCollection(
///     action: \AppAction.updateTodo,
///     stateCollection: \AppState.todos
/// )
/// sectionReducer.liftCollection(
///     action: \AppAction.expandSection,
///     stateCollection: \AppState.sections
/// )
/// configReducer.liftCollection(
///     action: \AppAction.updateConfig,
///     stateDictionary: \AppState.userConfig
/// )
/// ```
///
/// ## StoreProjection element factories
///
/// When you call ``StoreType/projection(element:actionReview:stateCollection:)`` or one of
/// its sibling overloads, the projection's `dispatch` closure automatically wraps the local
/// action in an `ElementAction` and passes it through `actionReview` to reach the global store.
/// The view dispatches only the local sub-action — the wiring is invisible.
///
/// ## Conditional conformances
///
/// `ElementAction` conditionally conforms to `Sendable`, `Equatable`, `Hashable`,
/// `Encodable`, and `Decodable` when both `ID` and `SubAction` satisfy the respective
/// constraints, making it safe to use in any context where those constraints are needed.
public struct ElementAction<ID, SubAction> {
    /// The identifier that selects the target element within a collection.
    public let id: ID
    /// The action to apply to the element identified by `id`.
    public let action: SubAction

    /// Creates an `ElementAction` pairing an identifier with a sub-action.
    ///
    /// ```swift
    /// let elementAction = ElementAction(todo.id, action: .toggleDone)
    /// ```
    ///
    /// - Parameters:
    ///   - id: The identifier of the target element.
    ///   - action: The sub-action to apply to that element.
    public init(_ id: ID, action: SubAction) {
        self.id = id
        self.action = action
    }
}

extension ElementAction: Sendable where ID: Sendable, SubAction: Sendable {}
extension ElementAction: Equatable where ID: Equatable, SubAction: Equatable {}
extension ElementAction: Hashable where ID: Hashable, SubAction: Hashable {}
extension ElementAction: Decodable where ID: Decodable, SubAction: Decodable {}
extension ElementAction: Encodable where ID: Encodable, SubAction: Encodable {}
extension ElementAction: CustomStringConvertible {
    public var description: String {
        "ElementAction(id: \(id), action: \(action))"
    }
}
