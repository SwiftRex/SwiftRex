import Foundation

enum MainAction: Equatable {
    /// subview Action
  case counterAction(CounterAction)
    /// view Action
  case viewOnAppear
  case viewOnDisappear
  case none
  case toggleTodo(TodoModel)
  case logout
  case changeRootScreen(RootScreen)
  case viewCreateTodo
    /// binding
  case changeText(String)
    /// network Action
  case getTodo
  case responseTodo(Data)
  case createOrUpdateTodo(TodoModel)
  case responseCreateOrUpdateTodo(Data)
  case updateTodo(TodoModel)
  case responseUpdateTodo(Data)
  case deleteTodo(TodoModel)
  case reponseDeleteTodo(Data)
}

extension MainAction {
  public var counterAction: CounterAction? {
    guard case let .counterAction(value) = self else { return nil }
    return value
  }
}
