import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let store = GlobalStore()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let viewController = self.window?.rootViewController as! ViewController
        viewController.stateProvider = store
        viewController.eventHandler = store
        return true
    }
}
