import UIKit
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    static var orientationLock = UIInterfaceOrientationMask.all
    var handleImageImport: ((URL) -> Void)?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化默认备份
        BackupManager.shared.copyDefaultBackupIfNeeded()
        
        // 创建窗口并设置根视图控制器
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIHostingController(rootView: ContentView())
        window?.makeKeyAndVisible()
        
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        BirdCountCache.shared.clear()
    }

    // 处理 URL Scheme
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("Received URL: \(url)")  // 添加日志
        
        // 处理 tuiportfolio URL Scheme
        if url.scheme == "tuiportfolio" {
            handleImageImport?(url)
            return true
        }
        
        // 处理其他类型的 URL（保留原有逻辑）
        let addImageView = AddImageView.handleIncomingURL(url)
        
        // 创建一个 UIHostingController 来承载 SwiftUI 视图
        let hostingController = UIHostingController(rootView: addImageView)
        
        // 将 hostingController 设置为根视图控制器
        self.window?.rootViewController = hostingController
        self.window?.makeKeyAndVisible()

        return true
    }
}
