import SwiftUI

@main
struct TodoApp: App {
  var body: some Scene {
    WindowGroup {
      let vc = RootViewController()
      UIViewRepresented(makeUIView: { _ in vc.view })
    }
  }
}
