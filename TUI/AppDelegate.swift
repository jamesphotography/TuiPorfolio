import UIKit
import SwiftUI

class AppDelegate: UIResponder, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化默认备份
        BackupManager.shared.copyDefaultBackupIfNeeded()
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        BirdCountCache.shared.clear()
    }
}
