import Foundation
import UIKit

class CloudSyncService {
    static let shared = CloudSyncService()
    
    private let baseURL = "https://james.james-727.workers.dev/api"
    private var isSyncing = false
    private var isUploading = false
    private var syncProgress: Float = 0.0
    private var uploadProgress: Float = 0.0
    private var totalPhotos: Int = 0
    private var syncedPhotos: Int = 0
    private var uploadedPhotos: Int = 0
    private var failedUploads: [(String, String)] = [] // (id, error)
    
    // 同步进度回调
    var progressCallback: ((Float, Int, Int, String) -> Void)?
    var completionCallback: ((Bool, String, [String]) -> Void)?
    
    // 测试模式 - 不上传实际文件，仅同步元数据
    var testMode: Bool = false
    
    // 文件类型枚举
    enum FileType {
        case original
        case thumbnail100
        case thumbnail350
        
        var suffix: String {
            switch self {
            case .original: return ".jpg"
            case .thumbnail100: return "_100.jpg"
            case .thumbnail350: return "_350.jpg"
            }
        }
        
        var folder: String {
            switch self {
            case .original: return "photos"
            case .thumbnail100, .thumbnail350: return "thumbnails"
            }
        }
    }
    
    private init() {}
    
    // 主同步方法，同步元数据和上传文件
    func syncAllPhotos(limit: Int? = nil) {
        print("CloudSync: 开始同步所有照片")
        
        guard !isSyncing else {
            print("CloudSync: 同步已在进行中")
            DispatchQueue.main.async {
                self.completionCallback?(false, "同步已在进行中", [])
            }
            return
        }
        
        isSyncing = true
        isUploading = false
        syncProgress = 0.0
        uploadProgress = 0.0
        syncedPhotos = 0
        uploadedPhotos = 0
        failedUploads = []
        
        // 获取所有照片
        var photos = SQLiteManager.shared.getAllPhotos()
        
        // 如果设置了限制，则只取前N张
        if let limit = limit {
            photos = Array(photos.prefix(limit))
        }
        
        totalPhotos = photos.count
        
        print("CloudSync: 找到 \(totalPhotos) 张照片需要同步")
        
        DispatchQueue.main.async {
            self.progressCallback?(0.0, 0, self.totalPhotos, "准备同步元数据...")
        }
        
        if totalPhotos == 0 {
            print("CloudSync: 没有找到需要同步的照片")
            isSyncing = false
            DispatchQueue.main.async {
                self.completionCallback?(false, "没有找到需要同步的照片", [])
            }
            return
        }
        
        // 将照片分批处理
        let batchSize = 5 // 每批5张照片，避免请求过大
        let totalBatches = (photos.count + batchSize - 1) / batchSize
        
        print("CloudSync: 将分 \(totalBatches) 批处理，每批 \(batchSize) 张照片")
        
        // 创建一个操作队列来处理这些批次
        let operationQueue = DispatchQueue(label: "com.tuiportfolio.batchsync", qos: .userInitiated)
        
        operationQueue.async {
            for batchIndex in 0..<totalBatches {
                if !self.isSyncing {
                    print("CloudSync: 同步已被取消，停止批处理")
                    break
                }
                
                let startIndex = batchIndex * batchSize
                let endIndex = min(startIndex + batchSize, photos.count)
                let batchPhotos = Array(photos[startIndex..<endIndex])
                
                print("CloudSync: 处理批次 \(batchIndex + 1)/\(totalBatches)，包含 \(batchPhotos.count) 张照片")
                
                // 同步这批照片的元数据
                self.syncBatch(photos: batchPhotos, batchIndex: batchIndex + 1, totalBatches: totalBatches)
                
                // 等待批次完成
                Thread.sleep(forTimeInterval: 1.0)
            }
            
            // 元数据同步完成后，开始上传文件
            if self.isSyncing && !self.testMode {
                self.uploadPhotoFiles(photos: photos)
            } else if self.isSyncing && self.testMode {
                // 测试模式，不上传文件
                print("CloudSync: 测试模式，跳过文件上传")
                DispatchQueue.main.async {
                    self.completionCallback?(true, "所有\(self.totalPhotos)张照片元数据同步成功（测试模式，未上传文件）", [])
                }
                self.isSyncing = false
            }
        }
    }
    
    private func syncBatch(photos: [Photo], batchIndex: Int, totalBatches: Int) {
        print("CloudSync: 开始同步批次 \(batchIndex)/\(totalBatches)，\(photos.count) 张照片")
        
        // 创建一个批量同步请求
        var photoDataArray: [[String: Any]] = []
        
        for photo in photos {
            // 将相对路径转换为云端路径
            let cloudPath = "photos/\(photo.id).jpg"
            let cloudThumb100 = "thumbnails/\(photo.id)_100.jpg"
            let cloudThumb350 = "thumbnails/\(photo.id)_350.jpg"
            
            let photoData: [String: Any] = [
                "id": photo.id,
                "title": photo.title,
                "path": cloudPath,
                "thumbnailPath100": cloudThumb100,
                "thumbnailPath350": cloudThumb350,
                "starRating": photo.starRating,
                "country": photo.country,
                "area": photo.area,
                "locality": photo.locality,
                "dateTimeOriginal": photo.dateTimeOriginal,
                "addTimestamp": photo.addTimestamp,
                "lensModel": photo.lensModel,
                "model": photo.model,
                "exposureTime": photo.exposureTime,
                "fNumber": photo.fNumber,
                "focalLenIn35mmFilm": photo.focalLenIn35mmFilm,
                "focalLength": photo.focalLength,
                "isoSPEEDRatings": photo.ISOSPEEDRatings,
                "altitude": photo.altitude,
                "latitude": photo.latitude,
                "longitude": photo.longitude,
                "objectName": photo.objectName,
                "caption": photo.caption
            ]
            photoDataArray.append(photoData)
        }
        
        let batchData: [String: Any] = ["photos": photoDataArray]
        
        print("CloudSync: 批次 \(batchIndex)/\(totalBatches) 准备发送元数据，\(photoDataArray.count) 条记录")
        
        // 同步元数据
        syncMetadata(batchData: batchData) { [weak self] success, message in
            guard let self = self else { return }
            
            if success {
                print("CloudSync: 批次 \(batchIndex)/\(totalBatches) 元数据同步成功")
                
                // 更新进度
                DispatchQueue.main.async {
                    self.syncedPhotos += photos.count
                    self.syncProgress = Float(self.syncedPhotos) / Float(self.totalPhotos)
                    print("CloudSync: 进度更新 - \(Int(self.syncProgress * 100))%，已同步 \(self.syncedPhotos)/\(self.totalPhotos)")
                    self.progressCallback?(self.syncProgress, self.syncedPhotos, self.totalPhotos, "同步元数据...")
                }
            } else {
                print("CloudSync: 批次 \(batchIndex)/\(totalBatches) 元数据同步失败: \(message)")
                
                // 如果失败，我们仍然尝试继续处理其他批次
                DispatchQueue.main.async {
                    // 更新进度，即使失败了
                    self.syncedPhotos += photos.count
                    self.syncProgress = Float(self.syncedPhotos) / Float(self.totalPhotos)
                    self.progressCallback?(self.syncProgress, self.syncedPhotos, self.totalPhotos, "同步元数据失败: \(message)...")
                }
            }
        }
    }
    
    private func syncMetadata(batchData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        print("CloudSync: 同步元数据到 \(baseURL)/sync")
        
        guard let url = URL(string: "\(baseURL)/sync") else {
            print("CloudSync: 无效的API URL")
            completion(false, "无效的API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: batchData)
            print("CloudSync: 已序列化JSON数据，准备发送")
        } catch {
            print("CloudSync: JSON序列化失败: \(error.localizedDescription)")
            completion(false, "JSON序列化失败: \(error.localizedDescription)")
            return
        }
        
        print("CloudSync: 发送网络请求...")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("CloudSync: 网络错误: \(error.localizedDescription)")
                completion(false, "网络错误: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("CloudSync: 无效的HTTP响应")
                completion(false, "无效的HTTP响应")
                return
            }
            
            print("CloudSync: 收到HTTP响应，状态码: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                print("CloudSync: 元数据同步成功")
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("CloudSync: 服务器响应: \(responseString)")
                }
                
                completion(true, "元数据同步成功")
            } else {
                var message = "服务器错误: \(httpResponse.statusCode)"
                if let data = data, let responseMessage = String(data: data, encoding: .utf8) {
                    message += " - \(responseMessage)"
                    print("CloudSync: 错误响应: \(responseMessage)")
                }
                print("CloudSync: \(message)")
                completion(false, message)
            }
        }
        
        task.resume()
    }
    
    // 上传照片文件
    private func uploadPhotoFiles(photos: [Photo]) {
        print("CloudSync: 开始上传照片文件")
        
        isUploading = true
        uploadedPhotos = 0
        uploadProgress = 0.0
        
        DispatchQueue.main.async {
            self.progressCallback?(0.0, 0, self.totalPhotos, "准备上传文件...")
        }
        
        // 将照片分批上传
        let uploadQueue = DispatchQueue(label: "com.tuiportfolio.fileupload", qos: .userInitiated, attributes: .concurrent)
        let uploadGroup = DispatchGroup()
        let uploadSemaphore = DispatchSemaphore(value: 2) // 限制并发上传数
        
        for (index, photo) in photos.enumerated() {
            uploadGroup.enter()
            uploadQueue.async {
                // 等待信号量，限制并发数
                uploadSemaphore.wait()
                
                // 上传原始文件
                self.uploadSingleFile(photo: photo, fileType: .original) { success, error in
                    if !success {
                        print("CloudSync: 上传原始照片失败: \(error)")
                        self.failedUploads.append((photo.id, "原图: \(error)"))
                    }
                    
                    // 上传缩略图100
                    self.uploadSingleFile(photo: photo, fileType: .thumbnail100) { success, error in
                        if !success {
                            print("CloudSync: 上传缩略图100失败: \(error)")
                            self.failedUploads.append((photo.id, "缩略图100: \(error)"))
                        }
                        
                        // 上传缩略图350
                        self.uploadSingleFile(photo: photo, fileType: .thumbnail350) { success, error in
                            if !success {
                                print("CloudSync: 上传缩略图350失败: \(error)")
                                self.failedUploads.append((photo.id, "缩略图350: \(error)"))
                            }
                            
                            // 更新进度
                            DispatchQueue.main.async {
                                self.uploadedPhotos += 1
                                self.uploadProgress = Float(self.uploadedPhotos) / Float(self.totalPhotos)
                                
                                // 计算总进度（元数据同步 + 文件上传）
                                let totalProgress = (self.syncProgress + self.uploadProgress) / 2.0
                                
                                let statusMessage = "上传文件 \(self.uploadedPhotos)/\(self.totalPhotos)..."
                                self.progressCallback?(totalProgress, self.uploadedPhotos, self.totalPhotos, statusMessage)
                                
                                if index % 10 == 0 || index == photos.count - 1 {
                                    print("CloudSync: 文件上传进度 - \(Int(self.uploadProgress * 100))%，已上传 \(self.uploadedPhotos)/\(self.totalPhotos)")
                                }
                            }
                            
                            // 释放信号量
                            uploadSemaphore.signal()
                            uploadGroup.leave()
                        }
                    }
                }
            }
        }
        
        // 等待所有上传完成
        uploadGroup.notify(queue: .main) {
            self.isUploading = false
            self.isSyncing = false
            
            // 如果有上传失败的照片，返回失败信息
            if !self.failedUploads.isEmpty {
                let failMessages = self.failedUploads.map { "照片ID \($0.0): \($0.1)" }
                self.completionCallback?(false, "照片同步完成，但有\(self.failedUploads.count)个文件上传失败", failMessages)
            } else {
                self.completionCallback?(true, "所有\(self.totalPhotos)张照片同步成功", [])
            }
        }
    }
    
    // 上传单个文件
    private func uploadSingleFile(photo: Photo, fileType: FileType, completion: @escaping (Bool, String) -> Void) {
        // 获取文件路径
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 确定本地和远程路径
        let localPath: String
        let remotePath: String
        
        switch fileType {
        case .original:
            localPath = photo.path
            remotePath = "\(fileType.folder)/\(photo.id)\(fileType.suffix)"
        case .thumbnail100:
            localPath = photo.thumbnailPath100
            remotePath = "\(fileType.folder)/\(photo.id)\(fileType.suffix)"
        case .thumbnail350:
            localPath = photo.thumbnailPath350
            remotePath = "\(fileType.folder)/\(photo.id)\(fileType.suffix)"
        }
        
        let localFileURL = documentsURL.appendingPathComponent(localPath)
        
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: localFileURL.path) else {
            print("CloudSync: 本地文件不存在: \(localFileURL.path)")
            completion(false, "本地文件不存在")
            return
        }
        
        // 读取文件数据
        guard let fileData = try? Data(contentsOf: localFileURL) else {
            print("CloudSync: 无法读取文件数据: \(localFileURL.path)")
            completion(false, "无法读取文件数据")
            return
        }
        
        // 创建上传请求
        guard let url = URL(string: "\(baseURL)/upload") else {
            completion(false, "无效的API URL")
            return
        }
        
        // 创建表单数据
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var httpBody = Data()
        
        // 添加路径参数
        httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        httpBody.append("Content-Disposition: form-data; name=\"path\"\r\n\r\n".data(using: .utf8)!)
        httpBody.append(remotePath.data(using: .utf8)!)
        httpBody.append("\r\n".data(using: .utf8)!)
        
        // 添加文件数据
        httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        httpBody.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(remotePath)\"\r\n".data(using: .utf8)!)
        httpBody.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        httpBody.append(fileData)
        httpBody.append("\r\n".data(using: .utf8)!)
        
        // 添加结束边界
        httpBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = httpBody
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("CloudSync: 文件上传错误: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "无效的HTTP响应")
                return
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                completion(true, "")
            } else {
                var errorMessage = "服务器响应错误: \(httpResponse.statusCode)"
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    errorMessage += " - \(responseBody)"
                }
                completion(false, errorMessage)
            }
        }
        
        task.resume()
    }
    
    func cancelSync() {
        if isSyncing {
            print("CloudSync: 取消同步")
            isSyncing = false
            isUploading = false
            DispatchQueue.main.async {
                self.completionCallback?(false, "同步已取消", [])
            }
        }
    }
    
    // 添加验证功能，检查同步是否成功
    func verifySync(sampleSize: Int = 10, completion: @escaping (Bool, String, Int) -> Void) {
        print("CloudSync: 开始验证同步结果")
        
        let allPhotos = SQLiteManager.shared.getAllPhotos()
        let actualSampleSize = min(sampleSize, allPhotos.count)
        
        if actualSampleSize == 0 {
            completion(false, "没有可验证的照片", 0)
            return
        }
        
        let randomIndices = (0..<allPhotos.count).shuffled().prefix(actualSampleSize)
        let samplePhotos = randomIndices.map { allPhotos[$0] }
        
        var foundCount = 0
        let group = DispatchGroup()
        
        for photo in samplePhotos {
            group.enter()
            
            checkPhotoExists(id: photo.id) { exists in
                if exists {
                    foundCount += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let success = foundCount == samplePhotos.count
            let message = success ?
                          "验证成功：所有\(foundCount)张样本照片都在云端找到" :
                          "验证部分失败：只有\(foundCount)/\(samplePhotos.count)张样本照片在云端找到"
            
            completion(success, message, foundCount)
        }
    }
    
    private func checkPhotoExists(id: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/photos/\(id)") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               data != nil {
                completion(true)
            } else {
                completion(false)
            }
        }
        
        task.resume()
    }
}
