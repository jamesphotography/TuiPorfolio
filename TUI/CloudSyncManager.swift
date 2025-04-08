import Foundation
import UIKit

/// 云同步管理器负责协调应用与CloudFlare Workers的同步操作
class CloudSyncManager {
    // 单例模式，确保全局访问同一个同步管理器实例
    static let shared = CloudSyncManager()
    
    // MARK: - 属性
    
    // 同步设置
    private var config: CloudSyncConfiguration {
        return CloudSyncConfiguration.shared
    }
    
    // 同步会话标识符
    private var currentSyncSessionId: String?
    
    // 同步状态
    private(set) var isSyncing = false
    private(set) var lastSyncError: Error?
    private(set) var lastSyncTime: Date?
    private(set) var syncProgress: Float = 0.0
    
    // 进度回调
    var progressHandler: ((Float) -> Void)?
    
    // 用于取消同步的令牌
    private var syncCancellationToken: Bool = false
    
    // MARK: - 初始化方法
    
    private init() {
        // 私有初始化方法，防止外部创建实例
    }
    
    // MARK: - 公共方法
    
    /// 开始同步操作
    /// - Parameters:
    ///   - forceFullSync: 是否强制进行完整同步
    ///   - completion: 同步完成后的回调
    public func startSync(forceFullSync: Bool = false, completion: @escaping (Bool, Error?) -> Void) {
        guard config.isConfigured else {
            completion(false, SyncError.notConfigured)
            return
        }
        
        guard !isSyncing else {
            completion(false, SyncError.alreadySyncing)
            return
        }
        
        isSyncing = true
        syncCancellationToken = false
        syncProgress = 0.0
        updateProgress(0.0)
        
        // 创建同步会话
        Task {
            do {
                // 初始化同步
                let sessionId = try await initializeSync(forceFullSync: forceFullSync)
                currentSyncSessionId = sessionId
                
                // 检查是否取消
                if syncCancellationToken {
                    throw SyncError.cancelled
                }
                
                // 同步记录
                try await syncRecords(sessionId: sessionId)
                
                // 检查是否取消
                if syncCancellationToken {
                    throw SyncError.cancelled
                }
                
                // 同步文件
                try await syncFiles(sessionId: sessionId)
                
                // 检查是否取消
                if syncCancellationToken {
                    throw SyncError.cancelled
                }
                
                // 完成同步
                try await finalizeSync(sessionId: sessionId)
                
                await MainActor.run {
                    self.isSyncing = false
                    self.lastSyncTime = Date()
                    self.lastSyncError = nil
                    self.syncProgress = 1.0
                    self.updateProgress(1.0)
                    completion(true, nil)
                }
            } catch {
                await MainActor.run {
                    self.isSyncing = false
                    self.lastSyncError = error
                    self.updateProgress(0.0)
                    completion(false, error)
                }
            }
        }
    }
    
    /// 取消正在进行的同步操作
    public func cancelSync() {
        if isSyncing {
            syncCancellationToken = true
        }
    }
    
    // MARK: - 私有方法
    
    /// 初始化同步会话
    /// - Parameter forceFullSync: 是否强制完整同步
    /// - Returns: 同步会话ID
    private func initializeSync(forceFullSync: Bool) async throws -> String {
        updateProgress(0.1)
        
        guard let workerUrl = config.workerUrl else {
            throw SyncError.invalidConfiguration
        }
        
        let endpoint = workerUrl.appendingPathComponent("sync/initialize")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(config.apiToken)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = await [
            "forceFullSync": forceFullSync,
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "lastSyncTime": lastSyncTime?.ISO8601Format() ?? ""
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            // 尝试从响应中解析错误信息
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SyncError.serverError(errorResponse.message)
            } else {
                throw SyncError.httpError(httpResponse.statusCode)
            }
        }
        
        // 解析响应
        let syncResponse = try JSONDecoder().decode(InitSyncResponse.self, from: data)
        
        return syncResponse.sessionId
    }
    
    /// 同步数据库记录
    /// - Parameter sessionId: 同步会话ID
    private func syncRecords(sessionId: String) async throws {
        // 获取待同步记录
        let pendingRecords = SQLiteManager.shared.getPendingSyncRecords(limit: 100)
        
        if pendingRecords.isEmpty {
            updateProgress(0.3) // 没有记录需要同步，直接前进到30%
            return
        }
        
        guard let workerUrl = config.workerUrl else {
            throw SyncError.invalidConfiguration
        }
        
        let endpoint = workerUrl.appendingPathComponent("sync/records")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(config.apiToken)", forHTTPHeaderField: "Authorization")
        
        // 准备记录数据
        var recordsData: [[String: Any]] = []
        
        for record in pendingRecords {
            let recordData: [String: Any] = [
                "id": record.id,
                "tableType": record.tableType,
                "recordId": record.recordId,
                "operationType": record.operationType.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: record.timestamp)
            ]
            recordsData.append(recordData)
        }
        
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "records": recordsData
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SyncError.serverError(errorResponse.message)
            } else {
                throw SyncError.httpError(httpResponse.statusCode)
            }
        }
        
        // 解析响应
        let syncResponse = try JSONDecoder().decode(SyncRecordsResponse.self, from: data)
        
        // 更新记录状态
        for result in syncResponse.results {
            if result.success {
                _ = SQLiteManager.shared.updateSyncRecordStatus(id: result.id, syncStatus: "SYNCED")
            } else {
                _ = SQLiteManager.shared.updateSyncRecordStatus(id: result.id, syncStatus: "FAILED", errorMessage: result.errorMessage)
            }
        }
        
        updateProgress(0.3)
    }
    
    /// 同步文件（照片）
    /// - Parameter sessionId: 同步会话ID
    private func syncFiles(sessionId: String) async throws {
        // 获取待同步的文件记录
        let pendingRecords = SQLiteManager.shared.getPendingSyncRecords(limit: 100)
            .filter { $0.tableType == "Photos" && $0.operationType != .delete }
        
        if pendingRecords.isEmpty {
            updateProgress(0.7) // 没有文件需要同步，直接前进到70%
            return
        }
        
        guard let workerUrl = config.workerUrl else {
            throw SyncError.invalidConfiguration
        }
        
        _ = workerUrl.appendingPathComponent("sync/files")
        
        // 为每个记录同步文件
        var filesProcessed = 0
        let totalFiles = pendingRecords.count
        
        for record in pendingRecords {
            // 检查是否取消
            if syncCancellationToken {
                throw SyncError.cancelled
            }
            
            // 获取照片信息
            guard let photo = getPhotoById(record.recordId) else {
                continue
            }
            
            // 获取文件路径
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let filePath = documentsDirectory.appendingPathComponent(photo.path)
            let thumbnail350Path = documentsDirectory.appendingPathComponent(photo.thumbnailPath350)
            
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: filePath.path) else {
                continue
            }
            
            // 上传文件
            let _ = try await uploadFile(sessionId: sessionId, recordId: record.recordId, filePath: filePath, fileType: "original")
            
            // 上传缩略图
            if FileManager.default.fileExists(atPath: thumbnail350Path.path) {
                _ = try await uploadFile(sessionId: sessionId, recordId: record.recordId, filePath: thumbnail350Path, fileType: "thumbnail350")
            }
            
            filesProcessed += 1
            let progress = 0.3 + 0.4 * (Float(filesProcessed) / Float(totalFiles))
            updateProgress(progress)
        }
        
        updateProgress(0.7)
    }
    
    /// 上传单个文件
    /// - Parameters:
    ///   - sessionId: 同步会话ID
    ///   - recordId: 记录ID
    ///   - filePath: 文件路径
    ///   - fileType: 文件类型（original、thumbnail350等）
    /// - Returns: 上传结果
    private func uploadFile(sessionId: String, recordId: String, filePath: URL, fileType: String) async throws -> Bool {
        guard let workerUrl = config.workerUrl else {
            throw SyncError.invalidConfiguration
        }
        
        let endpoint = workerUrl.appendingPathComponent("sync/files")
        
        // 创建multipart/form-data请求
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(config.apiToken)", forHTTPHeaderField: "Authorization")
        
        // 准备multipart表单数据
        var formData = Data()
        
        // 添加会话ID
        formData.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
        formData.append(sessionId.data(using: .utf8)!)
        
        // 添加记录ID
        formData.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"recordId\"\r\n\r\n".data(using: .utf8)!)
        formData.append(recordId.data(using: .utf8)!)
        
        // 添加文件类型
        formData.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"fileType\"\r\n\r\n".data(using: .utf8)!)
        formData.append(fileType.data(using: .utf8)!)
        
        // 添加文件数据
        formData.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filePath.lastPathComponent)\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        
        let fileData = try Data(contentsOf: filePath)
        formData.append(fileData)
        
        // 添加结束边界
        formData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = formData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SyncError.serverError(errorResponse.message)
            } else {
                throw SyncError.httpError(httpResponse.statusCode)
            }
        }
        
        // 解析响应
        let uploadResponse = try JSONDecoder().decode(UploadFileResponse.self, from: data)
        
        return uploadResponse.success
    }
    
    /// 完成同步会话
    /// - Parameter sessionId: 同步会话ID
    private func finalizeSync(sessionId: String) async throws {
        updateProgress(0.8)
        
        guard let workerUrl = config.workerUrl else {
            throw SyncError.invalidConfiguration
        }
        
        let endpoint = workerUrl.appendingPathComponent("sync/finalize")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(config.apiToken)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "sessionId": sessionId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw SyncError.serverError(errorResponse.message)
            } else {
                throw SyncError.httpError(httpResponse.statusCode)
            }
        }
        
        // 解析响应
        let _ = try JSONDecoder().decode(FinalizeSyncResponse.self, from: data)
        
        // 更新同步时间
        config.updateLastSyncTime()
        
        // 清理已同步的记录
        _ = SQLiteManager.shared.cleanupSyncedRecords()
        
        updateProgress(0.9)
    }
    
    /// 获取照片对象通过ID
    /// - Parameter id: 照片ID
    /// - Returns: 照片对象
    private func getPhotoById(_ id: String) -> Photo? {
        // 当前SQLiteManager没有通过ID获取照片的方法，需要遍历所有照片
        return SQLiteManager.shared.getAllPhotos().first { $0.id == id }
    }
    
    /// 更新同步进度
    /// - Parameter progress: 进度值（0.0-1.0）
    private func updateProgress(_ progress: Float) {
        DispatchQueue.main.async {
            self.syncProgress = progress
            self.progressHandler?(progress)
        }
    }
}

// MARK: - 模型

/// 错误响应模型
struct ErrorResponse: Codable {
    let success: Bool
    let message: String
}

/// 初始化同步响应
struct InitSyncResponse: Codable {
    let success: Bool
    let sessionId: String
    let message: String?
}

/// 同步记录结果
struct SyncRecordResult: Codable {
    let id: String
    let success: Bool
    let errorMessage: String?
}

/// 同步记录响应
struct SyncRecordsResponse: Codable {
    let success: Bool
    let results: [SyncRecordResult]
}

/// 文件上传响应
struct UploadFileResponse: Codable {
    let success: Bool
    let message: String?
}

/// 完成同步响应
struct FinalizeSyncResponse: Codable {
    let success: Bool
    let message: String?
    let summary: SyncSummary?
}

/// 同步摘要
struct SyncSummary: Codable {
    let recordsProcessed: Int
    let filesProcessed: Int
    let errors: Int
}

// MARK: - 错误枚举

/// 同步错误
enum SyncError: Error {
    case notConfigured
    case invalidConfiguration
    case alreadySyncing
    case cancelled
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case fileError(String)
}

extension SyncError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "云同步未配置"
        case .invalidConfiguration:
            return "云同步配置无效"
        case .alreadySyncing:
            return "同步已在进行中"
        case .cancelled:
            return "同步已取消"
        case .invalidResponse:
            return "服务器响应无效"
        case .httpError(let statusCode):
            return "HTTP错误: \(statusCode)"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .fileError(let message):
            return "文件错误: \(message)"
        }
    }
}
