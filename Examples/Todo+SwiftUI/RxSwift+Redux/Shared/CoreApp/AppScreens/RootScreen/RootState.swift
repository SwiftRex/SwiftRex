import Foundation

struct RootState: Equatable {
  var mainState = MainState()
  var authState = AuthState()
  var rootScreen: RootScreen = .main
}

enum RootScreen: Equatable {
    case main
    case auth
}
