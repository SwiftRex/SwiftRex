import Foundation
import SwiftRex
import Combine

class AuthMiddleware: MiddlewareProtocol {
  typealias InputActionType = AuthAction
  
  typealias OutputActionType = AuthAction
  
  typealias StateType = AuthState
  
  func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
    let sut = IO<OutputActionType> { output in
      switch action {
      case .login:
        output.dispatch(.changeRootScreen(.main))
      default:
        break
      }
    }
    return sut
  }
}
