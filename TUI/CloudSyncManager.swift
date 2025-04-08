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
    
    // 日志调试开关
    private let enableDebugLogs = true
    
    // 进度回调
    var progressHandler: ((Float) -> Void)?
    
    // 用于取消同步的令牌
    private var syncCancellationToken: Bool = false
    
    // MARK: - 初始化方法
    
    private init() {
        // 私有初始化方法，防止外部创建实例
        debugLog("CloudSyncManager 初始化")
    }
    
    // MARK: - 公共方法
    
    /// 开始同步操作
    /// - Parameters:
    ///   - forceFullSync: 是否强制进行完整同步
    ///   - completion: 同步完成后的回调
    public func startSync(forceFullSync: Bool = false, completion: @escaping (Bool, Error?) -> Void) {
        debugLog("开始同步请求 - 强制完整同步: \(forceFullSync)")
        
        guard config.isConfigured else {
            debugLog("错误: 同步未配置")
            completion(false, SyncError.notConfigured)
            return
        }
        
        guard !isSyncing else {
            debugLog("错误: 同步已在进行中")
            completion(false, SyncError.alreadySyncing)
            return
        }
        
        debugLog("Worker URL: \(config.workerUrl?.absoluteString ?? "未设置")")
        
        isSyncing = true
        syncCancellationToken = false
        syncProgress = 0.0
        updateProgress(0.0)
        
        // 创建同步会话
        Task {
            do {
                // 初始化同步
                debugLog("正在初始化同步...")
                let sessionId = try await initializeSync(forceFullSync: forceFullSync)
                currentSyncSessionId = sessionId
                debugLog("同步会话创建成功，会话ID: \(sessionId)")
                
                // 检查是否取消
                if syncCancellationToken {
                    debugLog("同步已取消")
                    throw SyncError.cancelled
                }
                
                // 同步记录
                debugLog("正在同步记录...")
                try await syncRecords(sessionId: sessionId)
                
                // 检查是否取消
                if syncCancellationToken {
                    debugLog("同步已取消")
                    throw SyncError.cancelled
                }
                
                // 同步文件
                debugLog("正在同步文件...")
                try await syncFiles(sessionId: sessionId)
                
                // 检查是否取消
                if syncCancellationToken {
                    debugLog("同步已取消")
                    throw SyncError.cancelled
                }
                
                // 完成同步
                debugLog("正在完成同步...")
                try await finalizeSync(sessionId: sessionId)
                
                await MainActor.run {
                    self.isSyncing = false
                    self.lastSyncTime = Date()
                    self.lastSyncError = nil
                    self.syncProgress = 1.0
                    self.updateProgress(1.0)
                    debugLog("同步成功完成")
                    completion(true, nil)
                }
            } catch {
                await MainActor.run {
                    self.isSyncing = false
                    self.lastSyncError = error
                    self.updateProgress(0.0)
                    debugLog("同步错误: \(error.localizedDescription)")
                    completion(false, error)
                }
            }
        }
    }
    
    /// 取消正在进行的同步操作
    public func cancelSync() {
        if isSyncing {
            debugLog("取消同步请求")
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
            debugLog("错误: Worker URL为空")
            throw SyncError.invalidConfiguration
        }
        
        let endpoint = workerUrl.appendingPathComponent("sync/initialize")
        debugLog("初始化同步 URL: \(endpoint.absoluteString)")
        
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
        
        debugLog("初始化同步请求数据: \(payload)")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLog("错误: 无效的HTTP响应")
                throw SyncError.invalidResponse
            }
            
            debugLog("初始化同步响应状态码: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                debugLog("初始化同步响应数据: \(responseString)")
            }
            
            if httpResponse.statusCode != 200 {
                // 尝试从响应中解析错误信息
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    debugLog("服务器错误: \(errorResponse.message)")
                    throw SyncError.serverError(errorResponse.message)
                } else {
                    debugLog("HTTP错误: \(httpResponse.statusCode)")
                    throw SyncError.httpError(httpResponse.statusCode)
                }
            }
            
            // 解析响应
            let syncResponse = try JSONDecoder().decode(InitSyncResponse.self, from: data)
            debugLog("初始化同步成功, 会话ID: \(syncResponse.sessionId)")
            
            return syncResponse.sessionId
        } catch {
            debugLog("初始化同步异常: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 同步数据库记录
    /// - Parameter sessionId: 同步会话ID
    private func syncRecords(sessionId: String) async throws {
        // 获取待同步记录
        let pendingRecords = SQLiteManager.shared.getPendingSyncRecords(limit: 100)
        
        debugLog("发现 \(pendingRecords.count) 条待同步记录")
        
        if pendingRecords.isEmpty {
            updateProgress(0.3) // 没有记录需要同步，直接前进到30%
            return
        }
        
        guard let workerUrl = config.workerUrl else {
            debugLog("错误: Worker URL为空")
            throw SyncError.invalidConfiguration
        }
        
        let endpoint = workerUrl.appendingPathComponent("sync/records")
        debugLog("同步记录 URL: \(endpoint.absoluteString)")
        
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
        
        debugLog("同步记录请求数据: sessionId=\(sessionId), 记录数=\(recordsData.count)")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLog("错误: 无效的HTTP响应")
                throw SyncError.invalidResponse
            }
            
            debugLog("同步记录响应状态码: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                debugLog("同步记录响应数据: \(responseString)")
            }
            
            if httpResponse.statusCode != 200 {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    debugLog("服务器错误: \(errorResponse.message)")
                    throw SyncError.serverError(errorResponse.message)
                } else {
                    debugLog("HTTP错误: \(httpResponse.statusCode)")
                    throw SyncError.httpError(httpResponse.statusCode)
                }
            }
            
            // 解析响应
            let syncResponse = try JSONDecoder().decode(SyncRecordsResponse.self, from: data)
            
            // 更新记录状态
            var successCount = 0
            var failureCount = 0
            
            for result in syncResponse.results {
                if result.success {
                    _ = SQLiteManager.shared.updateSyncRecordStatus(id: result.id, syncStatus: "SYNCED")
                    successCount += 1
                } else {
                    _ = SQLiteManager.shared.updateSyncRecordStatus(id: result.id, syncStatus: "FAILED", errorMessage: result.errorMessage)
                    failureCount += 1
                    debugLog("记录同步失败 ID: \(result.id), 错误: \(result.errorMessage ?? "未知错误")")
                }
            }
            
            debugLog("记录同步完成: 成功=\(successCount), 失败=\(failureCount)")
            
            updateProgress(0.3)
        } catch {
            debugLog("同步记录异常: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 同步文件（照片）
    /// - Parameter sessionId: 同步会话ID
    private func syncFiles(sessionId: String) async throws {
        // 获取待同步的文件记录
        let pendingRecords = SQLiteManager.shared.getPendingSyncRecords(limit: 100)
            .filter { $0.tableType == "Photos" && $0.operationType != .delete }
        
        debugLog("发现 \(pendingRecords.count) 个待同步文件")
        
        if pendingRecords.isEmpty {
            updateProgress(0.7) // 没有文件需要同步，直接前进到70%
            return
        }
        
        guard let workerUrl = config.workerUrl else {
            debugLog("错误: Worker URL为空")
            throw SyncError.invalidConfiguration
        }
        
        let endpoint = workerUrl.appendingPathComponent("sync/files")
        debugLog("同步文件 URL: \(endpoint.absoluteString)")
        
        // 为每个记录同步文件
        var filesProcessed = 0
        var filesSuccess = 0
        var filesFailed = 0
        let totalFiles = pendingRecords.count
        
        for record in pendingRecords {
            // 检查是否取消
            if syncCancellationToken {
                debugLog("同步已取消")
                throw SyncError.cancelled
            }
            
            // 获取照片信息
            guard let photo = getPhotoById(record.recordId) else {
                debugLog("未找到照片 ID: \(record.recordId)")
                continue
            }
            
            // 获取文件路径
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let filePath = documentsDirectory.appendingPathComponent(photo.path)
            let thumbnail350Path = documentsDirectory.appendingPathComponent(photo.thumbnailPath350)
            
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: filePath.path) else {
                debugLog("文件不存在: \(filePath.path)")
                continue
            }
            
            debugLog("正在上传文件 ID: \(record.recordId)")
            
            // 上传文件
            do {
                let originalResult = try await uploadFile(sessionId: sessionId, recordId: record.recordId, filePath: filePath, fileType: "original")
                
                if originalResult {
                    debugLog("原始文件上传成功: \(filePath.lastPathComponent)")
                    filesSuccess += 1
                } else {
                    debugLog("原始文件上传失败: \(filePath.lastPathComponent)")
                    filesFailed += 1
                }
                
                // 上传缩略图
                if FileManager.default.fileExists(atPath: thumbnail350Path.path) {
                    let thumbnailResult = try await uploadFile(sessionId: sessionId, recordId: record.recordId, filePath: thumbnail350Path, fileType: "thumbnail350")
                    
                    if thumbnailResult {
                        debugLog("缩略图上传成功: \(thumbnail350Path.lastPathComponent)")
                    } else {
                        debugLog("缩略图上传失败: \(thumbnail350Path.lastPathComponent)")
                    }
                } else {
                    debugLog("缩略图不存在: \(thumbnail350Path.path)")
                }
            } catch {
                debugLog("文件上传异常: \(error.localizedDescription)")
                filesFailed += 1
            }
            
            filesProcessed += 1
            let progress = 0.3 + 0.4 * (Float(filesProcessed) / Float(totalFiles))
            updateProgress(progress)
            
            debugLog("文件处理进度: \(filesProcessed)/\(totalFiles) (\(Int(progress * 100))%)")
        }
        
        debugLog("文件同步完成: 总数=\(filesProcessed), 成功=\(filesSuccess), 失败=\(filesFailed)")
        
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
            debugLog("错误: Worker URL为空")
            throw SyncError.invalidConfiguration
        }
        
        let endpoint = workerUrl.appendingPathComponent("sync/files")
        debugLog("上传文件 URL: \(endpoint.absoluteString), 文件类型: \(fileType), 文件: \(filePath.lastPathComponent)")
        
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
        
        do {
            let fileData = try Data(contentsOf: filePath)
            debugLog("文件大小: \(ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file))")
            formData.append(fileData)
            
            // 添加结束边界
            formData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = formData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLog("错误: 无效的HTTP响应")
                throw SyncError.invalidResponse
            }
            
            debugLog("上传文件响应状态码: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                debugLog("上传文件响应数据: \(responseString)")
            }
            
            if httpResponse.statusCode != 200 {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    debugLog("服务器错误: \(errorResponse.message)")
                    throw SyncError.serverError(errorResponse.message)
                } else {
                    debugLog("HTTP错误: \(httpResponse.statusCode)")
                    throw SyncError.httpError(httpResponse.statusCode)
                }
            }
            
            // 解析响应
            let uploadResponse = try JSONDecoder().decode(UploadFileResponse.self, from: data)
            
            return uploadResponse.success
        } catch {
            debugLog("上传文件失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 完成同步会话
    /// - Parameter sessionId: 同步会话ID
    private func finalizeSync(sessionId: String) async throws {
        updateProgress(0.8)
        
        guard let workerUrl = config.workerUrl else {
            debugLog("错误: Worker URL为空")
            throw SyncError.invalidConfiguration
        }
        
        let endpoint = workerUrl.appendingPathComponent("sync/finalize")
        debugLog("完成同步 URL: \(endpoint.absoluteString)")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(config.apiToken)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "sessionId": sessionId
        ]
        
        debugLog("完成同步请求数据: sessionId=\(sessionId)")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                debugLog("错误: 无效的HTTP响应")
                throw SyncError.invalidResponse
            }
            
            debugLog("完成同步响应状态码: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                debugLog("完成同步响应数据: \(responseString)")
            }
            
            if httpResponse.statusCode != 200 {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    debugLog("服务器错误: \(errorResponse.message)")
                    throw SyncError.serverError(errorResponse.message)
                } else {
                    debugLog("HTTP错误: \(httpResponse.statusCode)")
                    throw SyncError.httpError(httpResponse.statusCode)
                }
            }
            
            // 解析响应
            let finalizeResponse = try JSONDecoder().decode(FinalizeSyncResponse.self, from: data)
            
            if let summary = finalizeResponse.summary {
                debugLog("同步摘要: 记录=\(summary.recordsProcessed), 文件=\(summary.filesProcessed), 错误=\(summary.errors)")
            }
            
            // 更新同步时间
            config.updateLastSyncTime()
            
            // 清理已同步的记录
            let cleanupCount = SQLiteManager.shared.cleanupSyncedRecords()
            debugLog("清理已同步记录: \(cleanupCount)条")
            
            updateProgress(0.9)
        } catch {
            debugLog("完成同步异常: \(error.localizedDescription)")
            throw error
        }
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
    
    /// 输出调试日志
    /// - Parameter message: 日志消息
    private func debugLog(_ message: String) {
        if enableDebugLogs {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss.SSS"
            let timestamp = dateFormatter.string(from: Date())
            print("[\(timestamp)] [CloudSync] \(message)")
        }
    }
    
    /// 执行健康检查（用于验证Worker连接）
    public func performHealthCheck() async -> (Bool, String?) {
        guard let workerUrl = CloudSyncConfiguration.shared.workerUrl else {
                   return (false, "Worker URL未配置")
               }
               
               // 使用/api/hello替代/health作为健康检查端点
               let healthEndpoint = workerUrl.appendingPathComponent("api/hello")
               print("执行健康检查: \(healthEndpoint.absoluteString)")
               
               do {
                   let request = URLRequest(url: healthEndpoint)
                   let (data, response) = try await URLSession.shared.data(for: request)
                   
                   guard let httpResponse = response as? HTTPURLResponse else {
                       return (false, "无效的HTTP响应")
                   }
                   
                   print("健康检查响应状态码: \(httpResponse.statusCode)")
                   
                   if let responseString = String(data: data, encoding: .utf8) {
                       print("健康检查响应数据: \(responseString)")
                   }
                   
                   if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                       return (true, nil)
                   } else {
                       return (false, "服务器返回错误状态码: \(httpResponse.statusCode)")
                   }
               } catch {
                   print("健康检查异常: \(error.localizedDescription)")
                   return (false, "网络错误: \(error.localizedDescription)")
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
