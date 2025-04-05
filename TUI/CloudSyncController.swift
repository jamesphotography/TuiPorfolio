import Foundation
import UIKit
import SwiftUI

// 集中管理云同步的控制器
class CloudSyncController: ObservableObject {
    static let shared = CloudSyncController()
    
    @Published var isSyncing: Bool = false
    @Published var syncProgress: Float = 0.0
    @Published var syncedItems: Int = 0
    @Published var totalItems: Int = 0
    @Published var statusMessage: String = "准备同步..."
    @Published var failedItems: [String] = []
    @Published var lastSyncTime: Date?
    
    private var syncService = CloudSyncService.shared
    
    private init() {
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        syncService.progressCallback = { [weak self] progress, synced, total, status in
            DispatchQueue.main.async {
                self?.syncProgress = progress
                self?.syncedItems = synced
                self?.totalItems = total
                self?.statusMessage = status
            }
        }
        
        syncService.completionCallback = { [weak self] success, message, failedList in
            DispatchQueue.main.async {
                self?.isSyncing = false
                self?.failedItems = failedList
                
                if success {
                    self?.lastSyncTime = Date()
                    UserDefaults.standard.set(Date(), forKey: "lastCloudSyncTime")
                }
                
                // 发送通知，其他界面可以据此更新
                NotificationCenter.default.post(
                    name: .cloudSyncCompleted,
                    object: nil,
                    userInfo: [
                        "success": success,
                        "message": message,
                        "failedCount": failedList.count
                    ]
                )
            }
        }
    }
    
    func startSync(photoLimit: Int? = nil, testMode: Bool = false) {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncProgress = 0.0
        syncedItems = 0
        failedItems = []
        statusMessage = "准备同步..."
        
        // 设置同步选项
        syncService.testMode = testMode
        
        // 开始同步
        syncService.syncAllPhotos(limit: photoLimit)
    }
    
    func cancelSync() {
        syncService.cancelSync()
    }
    
    func verifySyncStatus(completion: @escaping (Bool, String, Int) -> Void) {
        syncService.verifySync(completion: completion)
    }
    
    var lastSyncTimeString: String {
        guard let lastSync = lastSyncTime ?? UserDefaults.standard.object(forKey: "lastCloudSyncTime") as? Date else {
            return "从未同步"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}

// 通知名称扩展
extension Notification.Name {
    static let cloudSyncCompleted = Notification.Name("com.tuiportfolio.cloudSyncCompleted")
}
