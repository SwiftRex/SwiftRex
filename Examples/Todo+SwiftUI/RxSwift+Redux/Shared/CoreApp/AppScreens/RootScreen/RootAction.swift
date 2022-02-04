import Foundation

enum RootAction: Equatable {
  case mainAction(MainAction)
  case authAction(AuthAction)
  case viewOnAppear
  case viewOnDisappear
  case none
  case changeRootScreen(RootScreen)
}

extension RootAction {
  public var mainAction: MainAction? {
    guard case let .mainAction(value) = self else { return nil }
    return value
  }
  public var authAction: AuthAction? {
    guard case let .authAction(value) = self else { return nil }
    return value
  }
}
