import SwiftUI
import Foundation

/// 用于验证CloudFlare配置的工具类
class CloudSyncValidator {
    /// 验证结果
    enum ValidationResult {
        /// 验证成功
        case success
        /// 验证失败，附带错误信息
        case failure(String)
        /// 验证过程中出现网络错误
        case networkError(Error)
    }
    
    /// 异步验证CloudFlare凭据
    /// - Parameters:
    ///   - apiToken: CloudFlare API令牌
    ///   - accountId: CloudFlare账户ID
    ///   - completion: 验证完成后的回调，传递验证结果
    static func validateCredentials(apiToken: String, accountId: String, completion: @escaping (ValidationResult) -> Void) {
        // 构建验证请求URL
        guard let url = URL(string: "https://api.cloudflare.com/client/v4/accounts/\(accountId)") else {
            completion(.failure("无效的账户ID格式"))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 执行请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // 检查网络错误
            if let error = error {
                completion(.networkError(error))
                return
            }
            
            // 检查HTTP状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure("无效的响应"))
                return
            }
            
            // 分析响应
            switch httpResponse.statusCode {
            case 200:
                // 验证通过
                completion(.success)
                
            case 401, 403:
                // 身份验证失败
                completion(.failure("API令牌无效或无权访问"))
                
            case 404:
                // 账户ID不存在
                completion(.failure("账户ID不存在"))
                
            default:
                // 其他错误
                if let data = data, let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errors = jsonObject["errors"] as? [[String: Any]], !errors.isEmpty,
                   let firstError = errors.first, let errorMessage = firstError["message"] as? String {
                    completion(.failure("CloudFlare错误: \(errorMessage)"))
                } else {
                    completion(.failure("未知错误 (HTTP \(httpResponse.statusCode))"))
                }
            }
        }
        
        // 启动任务
        task.resume()
    }
    
    /// 异步验证Worker是否可访问
    /// - Parameters:
    ///   - workerUrl: CloudFlare Worker的URL
    ///   - completion: 验证完成后的回调，传递验证结果
    static func validateWorkerAccess(workerUrl: URL, completion: @escaping (ValidationResult) -> Void) {
        // 构建健康检查URL
        let healthCheckUrl = workerUrl.appendingPathComponent("health")
        
        // 创建请求
        var request = URLRequest(url: healthCheckUrl)
        request.httpMethod = "GET"
        
        // 执行请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // 检查网络错误
            if let error = error {
                completion(.networkError(error))
                return
            }
            
            // 检查HTTP状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure("无效的响应"))
                return
            }
            
            // 分析响应
            switch httpResponse.statusCode {
            case 200...299:
                // Worker可访问
                completion(.success)
                
            case 404:
                // Worker不存在或健康检查端点未实现
                completion(.failure("Worker未找到或健康检查端点未实现"))
                
            default:
                // 其他错误
                completion(.failure("Worker返回错误 (HTTP \(httpResponse.statusCode))"))
            }
        }
        
        // 启动任务
        task.resume()
    }
    
    /// 异步全面验证配置
    /// - Parameters:
    ///   - config: CloudFlare同步配置
    ///   - completion: 验证完成后的回调，传递验证结果和错误信息
    static func validateFullConfiguration(_ config: CloudSyncConfiguration, completion: @escaping (Bool, String?) -> Void) {
        // 首先验证基本字段是否填写
        let validationResult = config.validateConfiguration()
        if !validationResult.isValid {
            completion(false, validationResult.errorMessage)
            return
        }
        
        // 验证API凭据
        validateCredentials(apiToken: config.apiToken, accountId: config.accountId) { result in
            switch result {
            case .success:
                // API凭据验证通过，继续验证Worker
                guard let workerUrl = config.workerUrl else {
                    completion(false, "无法构建有效的Worker URL")
                    return
                }
                
                validateWorkerAccess(workerUrl: workerUrl) { workerResult in
                    switch workerResult {
                    case .success:
                        // 所有验证通过
                        completion(true, nil)
                        
                    case .failure(let message):
                        completion(false, "Worker验证失败: \(message)")
                        
                    case .networkError(let error):
                        completion(false, "Worker验证网络错误: \(error.localizedDescription)")
                    }
                }
                
            case .failure(let message):
                completion(false, "API凭据验证失败: \(message)")
                
            case .networkError(let error):
                completion(false, "API凭据验证网络错误: \(error.localizedDescription)")
            }
        }
    }
}
