import SwiftRex
import SwiftUI
import UIKit
import ConvertSwift
import Combine
import CombineCocoa

final class MainViewController: BaseViewController {
  
  private let store: AnyStoreType<MainAction, MainState>
  @ObservedObject
  
  private var viewStore: ViewStore<MainAction, MainState>
  
  init(store: AnyStoreType<MainAction, MainState>? = nil) {
    let unwrapStore = store ?? ReduxStoreBase(
      subject: .combine(initialValue: MainState()),
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
    buttonLogout.tapPublisher
      .map{MainAction.logout}
      .subscribe(viewStore.action)
      .store(in: &cancellables)
    
    //bind viewstore to view
    viewStore.publisher.todos
      .sink { [weak self] _ in
        guard let self = self else {
          return
        }
        self.tableView.reloadData()
      }
      .store(in: &cancellables)
    
    viewStore.publisher.todos
      .map {$0.count.toString() + " Todos"}
      .assign(to: \.navigationItem.title, on: self)
      .store(in: &cancellables)
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

// MARK: - UITableViewDataSource
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
        .sink(receiveValue: { value in
          cell.buttonReload.isHidden = value
          if value {
            cell.activityIndicator.startAnimating()
          } else {
            cell.activityIndicator.stopAnimating()
          }
        })
        .store(in: &cell.cancellables)
      cell.buttonReload
        .tapPublisher
        .map{MainAction.getTodo}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
      return cell
    case 1:
      let cell = tableView.dequeueReusableCell(CreateTitleMainTableViewCell.self, for: indexPath)
      viewStore.publisher.title
        .map {$0}
        .assign(to: \.text, on: cell.titleTextField)
        .store(in: &cell.cancellables)
      viewStore.publisher.title.isEmpty
        .sink(receiveValue: { value in
          cell.createButton.setTitleColor(value ? UIColor(Color.gray) : UIColor(Color.green), for: .normal)
        })
        .store(in: &cell.cancellables)
      cell.createButton
        .tapPublisher
        .map {MainAction.viewCreateTodo}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
      cell.titleTextField
        .textPublisher
        .compactMap{$0}
        .map{MainAction.changeText($0)}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
      return cell
    case 2:
      let cell = tableView.dequeueReusableCell(MainTableViewCell.self, for: indexPath)
      let todo = viewStore.todos[indexPath.row]
      cell.bind(todo)
      cell.deleteButton
        .tapPublisher
        .map{MainAction.deleteTodo(todo)}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
      cell.tapGesture
        .tapPublisher
        .map {_ in MainAction.toggleTodo(todo)}
        .subscribe(viewStore.action)
        .store(in: &cell.cancellables)
      return cell
    default:
      let cell = tableView.dequeueReusableCell(MainTableViewCell.self, for: indexPath)
      return cell
    }
  }
}

  // MARK: - UITableViewDelegate
extension MainViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 60
  }
}
  // MARK: - PreviewProvider
struct MainViewController_Previews: PreviewProvider {
  static var previews: some View {
    let vc = MainViewController()
    UIViewRepresented(makeUIView: { _ in vc.view })
  }
}
