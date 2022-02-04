import Foundation

enum AuthAction: Equatable {
  case viewDidLoad
  case viewWillAppear
  case viewWillDisappear
  case none
  case login
  case changeRootScreen(RootScreen)
}
