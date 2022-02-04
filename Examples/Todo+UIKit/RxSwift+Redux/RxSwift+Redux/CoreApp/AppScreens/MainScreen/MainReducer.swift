import Foundation
import SwiftRex
import ConvertSwift
let MainReducer = Reducer<MainAction, MainState>.reduce { action, state in
  switch action {
    /// view action
  case .viewWillAppear:
    break
  case .viewWillDisappear:
    state = MainState()
  case .getTodo:
    if state.isLoading {
      return
    }
    state.isLoading = true
    state.todos.removeAll()
    break
  case .changeText(let text):
    state.title = text
  case .resetText:
    state.title = ""
      /// networking
  case .responseTodo(let data):
    state.isLoading = false
    if let todos = data.toModel([TodoModel].self) {
      state.todos = todos
    }
  case .responseCreateOrUpdateTodo(let data):
    state.title = ""
    if let todo = data.toModel(TodoModel.self) {
      state.todos.append(todo)
    }
  case .responseUpdateTodo(let data):
    if let todo = data.toModel(TodoModel.self) {
      if let index = state.todos.firstIndex(where: { item in
        item.id == todo.id
      }) {
        state.todos[index] = todo
      }
    }
  case .reponseDeleteTodo(let data):
    if let todo = data.toModel(TodoModel.self) {
      state.todos.removeAll {
        $0.id == todo.id
      }
    }
  default:
    break
  }
}

