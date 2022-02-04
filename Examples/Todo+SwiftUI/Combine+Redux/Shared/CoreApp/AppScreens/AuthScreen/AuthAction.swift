import Foundation

enum AuthAction: Equatable {
  case viewOnAppear
  case viewOnDisappear
  case none
  case login
  case changeRootScreen(RootScreen)
}
