import SwiftRex
import Combine

class CounterMiddleware: MiddlewareProtocol {
  
  typealias InputActionType = CounterAction
  
  typealias OutputActionType = CounterAction
  
  typealias StateType = CounterState

  func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
    let sut = IO<OutputActionType> { output in
      switch action {
      case .increment:
        print("increment")
      case .decrement:
        print("decrement")
      default:
        break
      }
    }
    return sut
  }
}
