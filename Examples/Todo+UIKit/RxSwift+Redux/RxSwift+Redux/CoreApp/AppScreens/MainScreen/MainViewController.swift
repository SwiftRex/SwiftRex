import SwiftRex
import SwiftUI
import UIKit
import ConvertSwift
import RxSwift
import RxCocoa

final class MainViewController: BaseViewController {
  
  private let store: AnyStoreType<MainAction, MainState>

  private var viewStore: ViewStore<MainAction, MainState>
  
  init(store: AnyStoreType<MainAction, MainState>? = nil) {
    let unwrapStore = store ?? ReduxStoreBase(
      subject: .rx(initialValue: MainState()),
      reducer: MainReducer,
      middleware: IdentityMiddleware<MainAction, MainAction, MainState>()
    )
      .eraseToAnyStoreType()
    self.store = unwrapStore
    self.viewStore = unwrapStore.asViewStore(initialState: MainState())
    super.init(nibName: nil, bundle: nil)
  }
  
  private let tableView: UITableView = UITableView()
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    viewStore.send(.viewDidLoad)
      // navigationView
    let buttonLogout = UIButton(type: .system)
    buttonLogout.setTitle("Logout", for: .normal)
    buttonLogout.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
    buttonLogout.setTitleColor(UIColor(Color.blue), for: .normal)
    let rightBarButtonItem = UIBarButtonItem(customView: buttonLogout)
    navigationController?.navigationBar.prefersLargeTitles = true
    navigationItem.largeTitleDisplayMode = .always
    navigationItem.rightBarButtonItem = rightBarButtonItem
      // tableView
    view.addSubview(tableView)
    tableView.register(MainTableViewCell.self)
    tableView.register(ButtonReloadMainTableViewCell.self)
    tableView.register(CreateTitleMainTableViewCell.self)
    tableView.showsVerticalScrollIndicator = false
    tableView.showsHorizontalScrollIndicator = false
    tableView.delegate = self
    tableView.dataSource = self
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.isUserInteractionEnabled = true
      // contraint
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
      tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
      tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
      tableView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -10)
    ])
    
    //bind view to viewstore
    buttonLogout.rx.tap
      .map{MainAction.logout}
      .subscribe(viewStore.action)
      .disposed(by: disposeBag)
    
    //bind viewstore to view
    viewStore.publisher.todos
      .subscribe(onNext: { [weak self] _ in
        guard let self = self else { return }
        self.tableView.reloadData()
      })
      .disposed(by: disposeBag)
      
    viewStore.publisher.todos
      .map {$0.count.toString() + " Todos"}
      .bind(to: navigationItem.rx.title)
      .disposed(by: disposeBag)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
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

extension MainViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 3
  }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0:
      return 1
    case 1:
      return 1
    case 2:
      return viewStore.todos.count
    default:
      return 0
    }
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case 0:
      let cell = tableView.dequeueReusableCell(ButtonReloadMainTableViewCell.self, for: indexPath)
      cell.selectionStyle = .none
      viewStore.publisher.isLoading
        .subscribe(onNext: { value in
          cell.buttonReload.isHidden = value
          if value {
            cell.activityIndicator.startAnimating()
          } else {
            cell.activityIndicator.stopAnimating()
          }
        })
        .disposed(by: cell.disposeBag)
      cell.buttonReload.rx.tap
        .map{MainAction.getTodo}
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      return cell
    case 1:
      let cell = tableView.dequeueReusableCell(CreateTitleMainTableViewCell.self, for: indexPath)
      viewStore.publisher.title
        .bind(to: cell.titleTextField.rx.text)
        .disposed(by: cell.disposeBag)
      viewStore.publisher.title.isEmpty
        .subscribe(onNext: { value in
          cell.createButton.setTitleColor(value ? UIColor(Color.gray) : UIColor(Color.green), for: .normal)
        })
        .disposed(by: cell.disposeBag)
      cell.createButton
        .rx.tap
        .map {MainAction.viewCreateTodo}
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      cell.titleTextField
        .rx.text.orEmpty
        .compactMap{$0}
        .map{MainAction.changeText($0)}
        .observe(on: MainScheduler.asyncInstance)
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      return cell
    case 2:
      let cell = tableView.dequeueReusableCell(MainTableViewCell.self, for: indexPath)
      let todo = viewStore.todos[indexPath.row]
      cell.bind(todo)
      cell.deleteButton
        .rx.tap
        .map{MainAction.deleteTodo(todo)}
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      cell.tapGesture
        .rx.event
        .map {_ in MainAction.toggleTodo(todo)}
        .bind(to: viewStore.action)
        .disposed(by: cell.disposeBag)
      return cell
    default:
      let cell = tableView.dequeueReusableCell(MainTableViewCell.self, for: indexPath)
      return cell
    }
  }
}

extension MainViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 60
  }
}

struct MainViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = MainViewController()
    UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
