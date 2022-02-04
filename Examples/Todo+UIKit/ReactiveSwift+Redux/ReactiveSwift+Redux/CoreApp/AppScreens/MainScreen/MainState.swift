import Foundation

struct MainState: Equatable {
  var counterState = CounterState()
  var title: String = ""
  var todos: [TodoModel] = []
  var isLoading: Bool = false
}
