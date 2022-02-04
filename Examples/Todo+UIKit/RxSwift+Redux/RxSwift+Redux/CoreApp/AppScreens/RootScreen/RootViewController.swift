import SwiftRex
import SwiftUI
import UIKit
import RxSwift
import RxCocoa

final class RootViewController: BaseViewController {
  
  private let store: ReduxStoreBase<RootAction, RootState>
  
  private var viewStore: ViewStore<RootAction, RootState>
  
  init(store: ReduxStoreBase<RootAction, RootState>? = nil) {
    let unwrapStore = store ?? ReduxStoreBase(
      subject: .rx(initialValue: RootState()),
      reducer: rootReducer,
      middleware: rootMiddleware
    )
    self.store = unwrapStore
    self.viewStore = unwrapStore.asViewStore(initialState: RootState())
    super.init(nibName: nil, bundle: nil)
  }
  
  private var viewController = UIViewController() {
    willSet {
      viewController.willMove(toParent: nil)
      viewController.view.removeFromSuperview()
      viewController.removeFromParent()
      addChild(newValue)
      newValue.view.frame = self.view.frame
      view.addSubview(newValue.view)
      newValue.didMove(toParent: self)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    viewStore.send(.viewDidLoad)
      //bind view to viewstore
    viewStore.publisher.rootScreen.subscribe(onNext: { [weak self] screen in
      guard let self = self else {return}
      switch screen {
      case .main:
        let vc = MainViewController(store: self.store.projection(action: RootAction.mainAction, state: {$0.mainState}))
        let nav = UINavigationController(rootViewController: vc)
        self.viewController = nav
      case .auth:
        let vc = AuthViewController(store: self.store.projection(action: RootAction.authAction, state: {$0.authState}))
        let nav = UINavigationController(rootViewController: vc)
        self.viewController = nav
      }
    })
    .disposed(by: disposeBag)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewStore.send(.viewWillAppear)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    viewStore.send(.viewWillDisappear)
  }
}

struct RootViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = RootViewController()
    UIViewRepresented(makeUIView: { _ in vc.view })
  }
}

