import SwiftRex
import ReactiveSwift
import ReactiveCocoa
import SwiftUI
import UIKit

final class CounterViewController: BaseViewController {
  
  private let store: AnyStoreType<CounterAction, CounterState>
  
  private var viewStore: ViewStore<CounterAction, CounterState>
  
  init(store: AnyStoreType<CounterAction, CounterState>? = nil) {
    let unwrapStore = store ?? ReduxStoreBase(
      subject: .reactive(initialValue: CounterState()),
      reducer: CounterReducer,
      middleware: IdentityMiddleware<CounterAction, CounterAction, CounterState>()
    )
      .eraseToAnyStoreType()
    self.store = unwrapStore
    self.viewStore = unwrapStore.asViewStore(initialState: CounterState())
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    viewStore.send(.viewDidLoad)
      // setup view
    self.view.backgroundColor = .systemBackground
      /// decrementButton
    let decrementButton = UIButton(type: .system)
    decrementButton.setTitle("−", for: .normal)
      /// countLabel
    let countLabel = UILabel()
    countLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .regular)
      /// incrementButton
    let incrementButton = UIButton(type: .system)
    incrementButton.setTitle("+", for: .normal)
    
      /// containerView
    let rootStackView = UIStackView(arrangedSubviews: [
      decrementButton,
      countLabel,
      incrementButton,
    ])
    rootStackView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(rootStackView)
    NSLayoutConstraint.activate([
      rootStackView.centerXAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerXAnchor),
      rootStackView.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor),
    ])
    
      //bind view to viewstore
    disposables += viewStore.action <~ decrementButton.reactive.controlEvents(.touchUpInside)
      .map {_ in CounterAction.decrement }
    
    disposables += viewStore.action <~ incrementButton.reactive.controlEvents(.touchUpInside)
      .map {_ in CounterAction.increment }
    
      //bind viewstore to view
    disposables += countLabel.reactive.text <~ viewStore.publisher.count.producer.map { $0.toString() }
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

struct CounterViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = CounterViewController()
    UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
