import Foundation
import SwiftRex

let RootReducer = Reducer<RootAction, RootState>.reduce { action, state in
  switch action {
  case .mainAction(let mainAction):
    print(mainAction)
  case .authAction(let authAction):
    print(authAction)
  case .changeRootScreen(let screen):
    state.rootScreen = screen
  default:
    break
  }
}
