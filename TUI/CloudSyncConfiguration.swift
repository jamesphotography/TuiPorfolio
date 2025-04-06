import SwiftUI
import Foundation

/// 管理CloudFlare同步功能的配置
class CloudSyncConfiguration {
    // 单例模式确保全局访问同一个配置对象
    static let shared = CloudSyncConfiguration()
    
    // MARK: - 配置键
    private struct ConfigKeys {
        static let apiToken = "cloudflare_api_token"
        static let accountId = "cloudflare_account_id"
        static let workerName = "cloudflare_worker_name"
        static let r2BucketName = "cloudflare_r2_bucket_name"
        static let d1DatabaseName = "cloudflare_d1_database_name"
        static let isConfigured = "cloudflare_is_configured"
        static let lastSyncTime = "cloudflare_last_sync_time"
    }
    
    // MARK: - 属性
    var apiToken: String {
        get { UserDefaults.standard.string(forKey: ConfigKeys.apiToken) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: ConfigKeys.apiToken) }
    }
    
    var accountId: String {
        get { UserDefaults.standard.string(forKey: ConfigKeys.accountId) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: ConfigKeys.accountId) }
    }
    
    var workerName: String {
        get { UserDefaults.standard.string(forKey: ConfigKeys.workerName) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: ConfigKeys.workerName) }
    }
    
    var r2BucketName: String {
        get { UserDefaults.standard.string(forKey: ConfigKeys.r2BucketName) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: ConfigKeys.r2BucketName) }
    }
    
    var d1DatabaseName: String {
        get { UserDefaults.standard.string(forKey: ConfigKeys.d1DatabaseName) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: ConfigKeys.d1DatabaseName) }
    }
    
    var isConfigured: Bool {
        get { UserDefaults.standard.bool(forKey: ConfigKeys.isConfigured) }
        set { UserDefaults.standard.set(newValue, forKey: ConfigKeys.isConfigured) }
    }
    
    var lastSyncTime: Date? {
        get { UserDefaults.standard.object(forKey: ConfigKeys.lastSyncTime) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: ConfigKeys.lastSyncTime) }
    }
    
    // MARK: - 构建完整的Worker URL
    var workerUrl: URL? {
        guard !workerName.isEmpty else { return nil }
        let urlString = "https://\(workerName).workers.dev"
        return URL(string: urlString)
    }
    
    // MARK: - 初始化
    private init() {}
    
    // MARK: - 配置管理方法
    func saveConfiguration(apiToken: String, accountId: String, workerName: String, r2BucketName: String, d1DatabaseName: String) -> Bool {
        guard !apiToken.isEmpty, !accountId.isEmpty, !workerName.isEmpty,
              !r2BucketName.isEmpty, !d1DatabaseName.isEmpty else {
            return false
        }
        self.apiToken = apiToken
        self.accountId = accountId
        self.workerName = workerName
        self.r2BucketName = r2BucketName
        self.d1DatabaseName = d1DatabaseName
        self.isConfigured = true
        return true
    }
    
    func validateConfiguration() -> ValidationResult {
        if apiToken.isEmpty { return .failure("API令牌未设置") }
        if accountId.isEmpty { return .failure("账户ID未设置") }
        if workerName.isEmpty { return .failure("Worker名称未设置") }
        if r2BucketName.isEmpty { return .failure("R2存储桶名称未设置") }
        if d1DatabaseName.isEmpty { return .failure("D1数据库名称未设置") }
        guard workerUrl != nil else { return .failure("无法构建有效的Worker URL") }
        return .success
    }
    
    func clearConfiguration() {
        apiToken = ""
        accountId = ""
        workerName = ""
        r2BucketName = ""
        d1DatabaseName = ""
        isConfigured = false
    }
    
    func updateLastSyncTime() {
        lastSyncTime = Date()
    }
    
    enum ValidationResult {
        case success
        case failure(String)
        var isValid: Bool {
            switch self {
            case .success: return true
            case .failure: return false
            }
        }
        var errorMessage: String? {
            switch self {
            case .success: return nil
            case .failure(let message): return message
            }
        }
    }
}
