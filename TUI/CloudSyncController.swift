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
    @Published var lastVerificationResult: CloudSyncVerifier.VerificationResult?
    @Published var isVerifying: Bool = false
    
    private var syncService = CloudSyncService.shared
    
    private init() {
        setupCallbacks()
        
        // 从 UserDefaults 加载上次同步时间
        if let lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudSyncTime") as? Date {
            self.lastSyncTime = lastSyncDate
        }
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
    
    // 验证同步状态
    func verifySyncStatus(sampleSize: Int = 20, forceRefresh: Bool = false, completion: @escaping (Bool, String, Int) -> Void) {
        isVerifying = true
        
        CloudSyncVerifier.shared.verifySync(sampleSize: sampleSize, forceRefresh: forceRefresh) { result in
            DispatchQueue.main.async {
                self.isVerifying = false
                self.lastVerificationResult = result
                
                // 转换为旧的返回格式以保持向后兼容
                let foundCount = result.verifiedPhotos - result.missingPhotos.count - result.metadataMismatch.count - result.fileIntegrityFailed.count
                completion(result.success, result.message, foundCount)
            }
        }
    }
    
    // 主动验证同步状态并获取完整结果
    func verifySync(sampleSize: Int = 20, forceRefresh: Bool = false, completion: @escaping (CloudSyncVerifier.VerificationResult) -> Void) {
        isVerifying = true
        
        CloudSyncVerifier.shared.verifySync(sampleSize: sampleSize, forceRefresh: forceRefresh) { result in
            DispatchQueue.main.async {
                self.isVerifying = false
                self.lastVerificationResult = result
                completion(result)
            }
        }
    }
    
    var lastSyncTimeString: String {
        guard let lastSync = lastSyncTime ?? UserDefaults.standard.object(forKey: "lastCloudSyncTime") as? Date else {
            return "从未同步"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
    
    // 同步状态概述
    var syncStatusSummary: String {
        if isSyncing {
            return "正在同步中 - \(syncedItems)/\(totalItems) 张照片"
        } else if let result = lastVerificationResult {
            if result.success {
                return "同步状态良好 - 已验证 \(result.verifiedPhotos) 张照片"
            } else {
                let issues = result.missingPhotos.count + result.metadataMismatch.count + result.fileIntegrityFailed.count
                return "同步存在问题 - \(issues) 个问题需要处理"
            }
        } else {
            return "未验证同步状态"
        }
    }
}

// 通知名称扩展
extension Notification.Name {
    static let cloudSyncCompleted = Notification.Name("com.tuiportfolio.cloudSyncCompleted")
    static let cloudSyncVerified = Notification.Name("com.tuiportfolio.cloudSyncVerified")
}
