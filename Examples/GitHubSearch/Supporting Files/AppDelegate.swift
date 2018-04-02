import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let store = GlobalStore()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let navigationController = self.window?.rootViewController as! UINavigationController
        navigationController.navigationBar.prefersLargeTitles = true
        let viewController = navigationController.viewControllers.first as! RepositorySearchViewController
        viewController.presenter = RepositorySearchPresenter(stateProvider: store, eventHandler: store)
        return true
    }
}
