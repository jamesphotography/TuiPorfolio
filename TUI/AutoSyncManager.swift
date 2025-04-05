import Foundation
import UIKit

class AutoSyncManager {
    static let shared = AutoSyncManager()
    
    private var timer: Timer?
    private let controller = CloudSyncController.shared
    private let userDefaults = UserDefaults.standard
    
    private init() {
        setupNotifications()
    }
    
    func setupNotifications() {
        // 应用进入前台时检查是否需要同步
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // 网络状态变化时检查
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: .networkStatusChanged,
            object: nil
        )
    }
    
    @objc func applicationDidBecomeActive() {
        checkAndSync()
    }
    
    @objc func networkStatusChanged() {
        if NetworkMonitor.shared.canSync() {
            checkAndSync()
        }
    }
    
    func start() {
        // 停止现有定时器
        timer?.invalidate()
        
        // 如果不启用自动同步，则直接返回
        if !userDefaults.bool(forKey: "cloudSyncAutomatically") {
            return
        }
        
        // 设置同步频率检查
        let timeInterval: TimeInterval
        
        switch userDefaults.integer(forKey: "cloudSyncFrequency") {
        case 1: // 每天
            timeInterval = 24 * 60 * 60
        case 2: // 每周
            timeInterval = 7 * 24 * 60 * 60
        case 3: // 每月
            timeInterval = 30 * 24 * 60 * 60
        default: // 从不或未知
            return
        }
        
        // 创建定时器
        timer = Timer.scheduledTimer(
            timeInterval: timeInterval,
            target: self,
            selector: #selector(checkAndSync),
            userInfo: nil,
            repeats: true
        )
        
        // 首次检查
        checkAndSync()
    }
    
    @objc func checkAndSync() {
        // 如果同步已在进行中，则跳过
        if controller.isSyncing {
            return
        }
        
        // 检查网络状态
        if !NetworkMonitor.shared.canSync() {
            return
        }
        
        // 检查是否启用自动同步
        if !userDefaults.bool(forKey: "cloudSyncAutomatically") {
            return
        }
        
        // 获取上次同步时间
        let lastSyncTime = userDefaults.object(forKey: "lastCloudSyncTime") as? Date
        
        // 确定是否需要同步
        let shouldSync: Bool
        
        if lastSyncTime == nil {
            // 从未同步过
            shouldSync = true
        } else {
            let now = Date()
            let syncFrequency = userDefaults.integer(forKey: "cloudSyncFrequency")
            
            switch syncFrequency {
            case 1: // 每天
                let dayDiff = Calendar.current.dateComponents([.day], from: lastSyncTime!, to: now).day ?? 0
                shouldSync = dayDiff >= 1
            case 2: // 每周
                let weekDiff = Calendar.current.dateComponents([.weekOfYear], from: lastSyncTime!, to: now).weekOfYear ?? 0
                shouldSync = weekDiff >= 1
            case 3: // 每月
                let monthDiff = Calendar.current.dateComponents([.month], from: lastSyncTime!, to: now).month ?? 0
                shouldSync = monthDiff >= 1
            default: // 从不或未知
                shouldSync = false
            }
        }
        
        // 如果需要同步，开始同步
        if shouldSync {
            // 自动同步使用测试模式，只同步元数据
            controller.startSync(testMode: true)
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }
}
