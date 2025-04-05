import Foundation
import UIKit

// 同步验证器 - 负责验证本地数据与云端数据的同步状态
class CloudSyncVerifier {
    static let shared = CloudSyncVerifier()
    
    private let baseURL = "https://james.james-727.workers.dev/api"
    
    // 验证结果
    struct VerificationResult {
        let success: Bool                    // 整体验证是否成功
        let totalLocalPhotos: Int            // 本地照片总数
        let totalCloudPhotos: Int            // 云端照片总数
        let verifiedPhotos: Int              // 已验证的照片数
        let missingPhotos: [String]          // 云端缺失的照片ID
        let metadataMismatch: [String]       // 元数据不匹配的照片ID
        let fileIntegrityFailed: [String]    // 文件完整性检查失败的照片ID
        let message: String                  // 结果概述消息
        let detailedReport: String           // 详细报告
    }
    
    // 验证缓存 - 避免短时间内重复验证
    private var lastVerificationResult: VerificationResult?
    private var lastVerificationTime: Date?
    private let cacheValidityDuration: TimeInterval = 60 * 5 // 5分钟缓存有效期
    
    private init() {}
    
    // 主验证方法
    func verifySync(sampleSize: Int = 0, forceRefresh: Bool = false, completion: @escaping (VerificationResult) -> Void) {
        print("开始验证同步状态，样本大小：\(sampleSize), 强制刷新：\(forceRefresh)")
        
        // 检查缓存
        if !forceRefresh,
           let lastResult = lastVerificationResult,
           let lastTime = lastVerificationTime,
           Date().timeIntervalSince(lastTime) < cacheValidityDuration {
            print("使用缓存的验证结果")
            completion(lastResult)
            return
        }
        
        // 获取本地照片
        let allLocalPhotos = SQLiteManager.shared.getAllPhotos()
        print("本地照片总数：\(allLocalPhotos.count)")
        
        // 确定实际验证样本大小
        var photosToVerify: [Photo]
        if sampleSize <= 0 || sampleSize >= allLocalPhotos.count {
            // 验证全部照片
            photosToVerify = allLocalPhotos
            print("将验证全部 \(photosToVerify.count) 张照片")
        } else {
            // 随机抽样验证
            let randomIndices = (0..<allLocalPhotos.count).shuffled().prefix(sampleSize)
            photosToVerify = randomIndices.map { allLocalPhotos[$0] }
            print("将验证 \(photosToVerify.count) 张随机照片")
        }
        
        // 获取云端照片总数
        getCloudPhotoCount { [weak self] totalCloudPhotos in
            guard let self = self else { return }
            
            print("云端照片总数：\(totalCloudPhotos)")
            
            // 开始分批验证照片
            self.verifyPhotosBatch(
                photos: photosToVerify,
                totalLocalPhotos: allLocalPhotos.count,
                totalCloudPhotos: totalCloudPhotos,
                verifiedCount: 0,
                missingPhotos: [],
                metadataMismatch: [],
                fileIntegrityFailed: [],
                completion: completion
            )
        }
    }
    
    // 分批验证照片，避免一次性发送过多请求
    private func verifyPhotosBatch(
        photos: [Photo],
        totalLocalPhotos: Int,
        totalCloudPhotos: Int,
        verifiedCount: Int,
        missingPhotos: [String],
        metadataMismatch: [String],
        fileIntegrityFailed: [String],
        completion: @escaping (VerificationResult) -> Void
    ) {
        // 每批验证的照片数量
        let batchSize = 5
        
        // 处理当前批次
        let currentBatch = Array(photos.prefix(batchSize))
        let remainingPhotos = Array(photos.dropFirst(min(batchSize, photos.count)))
        
        // 如果当前批次为空，验证完成
        if currentBatch.isEmpty {
            let success = missingPhotos.isEmpty && metadataMismatch.isEmpty && fileIntegrityFailed.isEmpty
            let message = generateSummaryMessage(
                success: success,
                totalLocalPhotos: totalLocalPhotos,
                totalCloudPhotos: totalCloudPhotos,
                verifiedPhotos: verifiedCount,
                missingPhotos: missingPhotos.count,
                metadataMismatch: metadataMismatch.count,
                fileIntegrityFailed: fileIntegrityFailed.count
            )
            
            let detailedReport = generateDetailedReport(
                totalLocalPhotos: totalLocalPhotos,
                totalCloudPhotos: totalCloudPhotos,
                verifiedPhotos: verifiedCount,
                missingPhotos: missingPhotos,
                metadataMismatch: metadataMismatch,
                fileIntegrityFailed: fileIntegrityFailed
            )
            
            let result = VerificationResult(
                success: success,
                totalLocalPhotos: totalLocalPhotos,
                totalCloudPhotos: totalCloudPhotos,
                verifiedPhotos: verifiedCount,
                missingPhotos: missingPhotos,
                metadataMismatch: metadataMismatch,
                fileIntegrityFailed: fileIntegrityFailed,
                message: message,
                detailedReport: detailedReport
            )
            
            // 缓存结果
            self.lastVerificationResult = result
            self.lastVerificationTime = Date()
            
            completion(result)
            return
        }
        
        // 创建验证组
        let group = DispatchGroup()
        
        // 当前批次的临时结果
        var newMissingPhotos = missingPhotos
        var newMetadataMismatch = metadataMismatch
        var newFileIntegrityFailed = fileIntegrityFailed
        
        // 验证当前批次的每张照片
        for photo in currentBatch {
            group.enter()
            
            // 验证单张照片
            verifyPhoto(photo) { exists, metadataMatch, fileIntegrityOK in
                defer { group.leave() }
                
                if !exists {
                    newMissingPhotos.append(photo.id)
                } else if !metadataMatch {
                    newMetadataMismatch.append(photo.id)
                } else if !fileIntegrityOK {
                    newFileIntegrityFailed.append(photo.id)
                }
            }
        }
        
        // 当前批次验证完成后，继续下一批次
        group.notify(queue: .main) {
            self.verifyPhotosBatch(
                photos: remainingPhotos,
                totalLocalPhotos: totalLocalPhotos,
                totalCloudPhotos: totalCloudPhotos,
                verifiedCount: verifiedCount + currentBatch.count,
                missingPhotos: newMissingPhotos,
                metadataMismatch: newMetadataMismatch,
                fileIntegrityFailed: newFileIntegrityFailed,
                completion: completion
            )
        }
    }
    
    // 验证单张照片
    private func verifyPhoto(_ photo: Photo, completion: @escaping (Bool, Bool, Bool) -> Void) {
        // 检查照片是否存在
        checkPhotoExists(id: photo.id) { exists in
            if !exists {
                completion(false, false, false)
                return
            }
            
            // 检查元数据
            self.verifyPhotoMetadata(photo) { metadataMatch in
                // 检查文件完整性
                self.verifyFileIntegrity(photo) { fileIntegrityOK in
                    completion(true, metadataMatch, fileIntegrityOK)
                }
            }
        }
    }
    
    
    
    // 检查照片是否存在于云端
    private func checkPhotoExists(id: String, completion: @escaping (Bool) -> Void) {
        // 注意：这里的路径已经是API路径，不需要添加.jpg后缀
        // 因为Worker端的路由是通过/api/photos/:id匹配的
        let urlString = "\(baseURL)/photos/\(id)"
        print("检查照片是否存在: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("无效的URL: \(urlString)")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("检查照片存在性时出错: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                print("照片检查状态码: \(statusCode)")
                
                if statusCode == 200 {
                    // 照片存在且文件也存在
                    print("照片存在: \(id)")
                    completion(true)
                    return
                } else if statusCode == 204 {
                    // 数据库有记录但文件不存在
                    // 在测试模式下可以认为是成功的
                    let isTestMode = UserDefaults.standard.bool(forKey: "cloudSyncTestMode")
                    print("照片在数据库中存在但文件缺失: \(id), 测试模式: \(isTestMode)")
                    completion(isTestMode)
                    return
                }
            }
            
            print("照片不存在: \(id)")
            completion(false)
        }
        
        task.resume()
    }
    
    // 验证照片元数据
    private func verifyPhotoMetadata(_ photo: Photo, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/metadata/\(photo.id)") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(false)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let metadata = json["metadata"] as? [String: Any] {
                    
                    // 检查关键元数据字段
                    let titleMatch = (metadata["title"] as? String == photo.title)
                    let dateMatch = (metadata["dateTimeOriginal"] as? String == photo.dateTimeOriginal)
                    let locationMatch = self.checkLocationMatch(
                        cloudLatitude: metadata["latitude"] as? Double,
                        cloudLongitude: metadata["longitude"] as? Double,
                        localLatitude: photo.latitude,
                        localLongitude: photo.longitude
                    )
                    
                    // 所有关键字段都匹配才算元数据匹配
                    completion(titleMatch && dateMatch && locationMatch)
                } else {
                    completion(false)
                }
            } catch {
                completion(false)
            }
        }
        
        task.resume()
    }
    
    // 检查位置信息是否匹配（允许微小误差）
    private func checkLocationMatch(cloudLatitude: Double?, cloudLongitude: Double?, localLatitude: Double, localLongitude: Double) -> Bool {
        guard let cloudLat = cloudLatitude, let cloudLong = cloudLongitude else {
            return false
        }
        
        // 允许0.00001度的误差（约1米）
        let latDiff = abs(cloudLat - localLatitude)
        let longDiff = abs(cloudLong - localLongitude)
        
        return latDiff < 0.00001 && longDiff < 0.00001
    }
    
    // 验证文件完整性
    private func verifyFileIntegrity(_ photo: Photo, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/files/integrity/\(photo.id)") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(false)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let integrity = json["integrity"] as? [String: Any],
                   let isIntact = integrity["isIntact"] as? Bool {
                    
                    completion(isIntact)
                } else {
                    completion(false)
                }
            } catch {
                completion(false)
            }
        }
        
        task.resume()
    }
    
    // 获取云端照片总数
    private func getCloudPhotoCount(completion: @escaping (Int) -> Void) {
        print("正在获取云端照片总数...")
        guard let url = URL(string: "\(baseURL)/files/count") else {
            print("无效的API URL")
            completion(0)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("获取照片数量时网络错误: \(error.localizedDescription)")
                completion(0)
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("获取照片数量请求失败")
                completion(0)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let count = json["count"] as? Int {
                    print("从API获取到云端照片数量: \(count)")
                    completion(count)
                } else {
                    print("无法解析云端照片数量响应")
                    completion(0)
                }
            } catch {
                print("解析照片数量JSON错误: \(error.localizedDescription)")
                completion(0)
            }
        }
        
        task.resume()
    }

    // 尝试直接从R2存储桶获取对象数量
    private func getR2ObjectCount(completion: @escaping (Int) -> Void) {
        guard let url = URL(string: "\(baseURL)/files/count") else {
            completion(0)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error getting R2 object count: \(error.localizedDescription)")
                completion(0)
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(0)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let count = json["count"] as? Int {
                    completion(count)
                } else {
                    completion(0)
                }
            } catch {
                print("Error parsing R2 object count: \(error.localizedDescription)")
                completion(0)
            }
        }
        
        task.resume()
    }
    
    // 生成验证摘要消息
    private func generateSummaryMessage(success: Bool, totalLocalPhotos: Int, totalCloudPhotos: Int, verifiedPhotos: Int, missingPhotos: Int, metadataMismatch: Int, fileIntegrityFailed: Int) -> String {
        if success {
            return "同步验证成功！已验证 \(verifiedPhotos) 张照片均已完全同步。"
        } else {
            var message = "同步验证失败。"
            message += " 本地照片: \(totalLocalPhotos)，云端照片: \(totalCloudPhotos)。"
            
            if missingPhotos > 0 {
                message += " 有 \(missingPhotos) 张照片未在云端找到。"
            }
            
            if metadataMismatch > 0 {
                message += " 有 \(metadataMismatch) 张照片元数据不匹配。"
            }
            
            if fileIntegrityFailed > 0 {
                message += " 有 \(fileIntegrityFailed) 张照片文件完整性验证失败。"
            }
            
            return message
        }
    }
    
    // 生成详细报告
    private func generateDetailedReport(totalLocalPhotos: Int, totalCloudPhotos: Int, verifiedPhotos: Int, missingPhotos: [String], metadataMismatch: [String], fileIntegrityFailed: [String]) -> String {
        var report = "# 同步验证详细报告\n\n"
        
        report += "## 概览\n"
        report += "- 本地照片总数: \(totalLocalPhotos)\n"
        report += "- 云端照片总数: \(totalCloudPhotos)\n"
        report += "- 已验证照片数: \(verifiedPhotos)\n"
        report += "- 同步差异率: \(calculateDifferenceRate(totalLocalPhotos, totalCloudPhotos))%\n\n"
        
        if !missingPhotos.isEmpty {
            report += "## 云端缺失的照片 (\(missingPhotos.count))\n"
            for (index, id) in missingPhotos.prefix(10).enumerated() {
                report += "\(index + 1). ID: \(id)\n"
            }
            if missingPhotos.count > 10 {
                report += "...(以及其他 \(missingPhotos.count - 10) 张照片)\n"
            }
            report += "\n"
        }
        
        if !metadataMismatch.isEmpty {
            report += "## 元数据不匹配的照片 (\(metadataMismatch.count))\n"
            for (index, id) in metadataMismatch.prefix(10).enumerated() {
                report += "\(index + 1). ID: \(id)\n"
            }
            if metadataMismatch.count > 10 {
                report += "...(以及其他 \(metadataMismatch.count - 10) 张照片)\n"
            }
            report += "\n"
        }
        
        if !fileIntegrityFailed.isEmpty {
            report += "## 文件完整性验证失败的照片 (\(fileIntegrityFailed.count))\n"
            for (index, id) in fileIntegrityFailed.prefix(10).enumerated() {
                report += "\(index + 1). ID: \(id)\n"
            }
            if fileIntegrityFailed.count > 10 {
                report += "...(以及其他 \(fileIntegrityFailed.count - 10) 张照片)\n"
            }
            report += "\n"
        }
        
        report += "## 建议\n"
        
        if missingPhotos.isEmpty && metadataMismatch.isEmpty && fileIntegrityFailed.isEmpty {
            report += "- 所有验证的照片均已完全同步，无需采取进一步操作。\n"
        } else {
            if !missingPhotos.isEmpty {
                report += "- 请重新同步云端缺失的照片。\n"
            }
            if !metadataMismatch.isEmpty {
                report += "- 元数据不匹配的照片需要重新更新元数据。\n"
            }
            if !fileIntegrityFailed.isEmpty {
                report += "- 文件完整性验证失败的照片需要重新上传。\n"
            }
            
            report += "- 考虑进行完整的重新同步以确保数据一致性。\n"
        }
        
        report += "\n验证时间: \(formattedDate(Date()))"
        
        return report
    }
    
    // 计算同步差异率
    private func calculateDifferenceRate(_ localCount: Int, _ cloudCount: Int) -> String {
        guard localCount > 0 else { return "100.0" }
        
        let difference = abs(localCount - cloudCount)
        let differenceRate = Double(difference) / Double(localCount) * 100
        
        return String(format: "%.1f", differenceRate)
    }
    
    // 格式化日期
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
