import Photos
import UIKit
import Foundation

public struct ImportResult: Identifiable {
    public let id = UUID()
    public let originalFileName: String
    public let status: ImportStatus
    public let reason: String?
    public let thumbnail: UIImage?
    
    public enum ImportStatus {
        case success
        case failure
    }
}

public class BulkImportManager {
    public static let shared = BulkImportManager()
    private init() {}
    
    private var importResults: [ImportResult] = []
    private let batchSize = 3
    
    public func importPhotos(from album: PHAssetCollection, progressHandler: @escaping (Float, Int, Int) -> Void, completionHandler: @escaping ([ImportResult]) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized, .limited:
                let assets = PHAsset.fetchAssets(in: album, options: nil)
                let totalAssets = assets.count
                
                self.importBatch(assets: assets, totalAssets: totalAssets, currentIndex: 0, successCount: 0, failureCount: 0, progressHandler: progressHandler) { results in
                    completionHandler(results)
                }
            case .denied:
                self.handleImportError(TuiImporterError.photoLibraryAccessDenied)
                completionHandler([])
            case .restricted:
                self.handleImportError(TuiImporterError.photoLibraryAccessRestricted)
                completionHandler([])
            case .notDetermined:
                self.handleImportError(TuiImporterError.unknown)
                completionHandler([])
            @unknown default:
                self.handleImportError(TuiImporterError.unknown)
                completionHandler([])
            }
        }
    }
    
    private func importBatch(assets: PHFetchResult<PHAsset>, totalAssets: Int, currentIndex: Int, successCount: Int, failureCount: Int, progressHandler: @escaping (Float, Int, Int) -> Void, completionHandler: @escaping ([ImportResult]) -> Void) {
        let endIndex = min(currentIndex + batchSize, totalAssets)
        let group = DispatchGroup()
        
        for i in currentIndex..<endIndex {
            group.enter()
            let asset = assets[i]
            
            // 获取原始文件名
            let resources = PHAssetResource.assetResources(for: asset)
            let originalFileName = resources.first?.originalFilename ?? "Unknown"
            
            BulkImportHelper.importAsset(asset) { success, reason, thumbnail in
                let result = ImportResult(
                    originalFileName: originalFileName,
                    status: success ? .success : .failure,
                    reason: reason,
                    thumbnail: thumbnail
                )
                DispatchQueue.main.async {
                    if success {
                        let newSuccessCount = successCount + 1
                        progressHandler(Float(i + 1) / Float(totalAssets), newSuccessCount, failureCount)
                    } else {
                        let newFailureCount = failureCount + 1
                        progressHandler(Float(i + 1) / Float(totalAssets), successCount, newFailureCount)
                    }
                    self.importResults.append(result)
                    group.leave()
                }
            }
            //UserDefaults.standard.set(false, forKey: "isFirstLaunch")
        }
        
        group.notify(queue: .main) {
            SQLiteManager.shared.commitTransaction()
            
            let newSuccessCount = self.importResults.filter { $0.status == .success }.count
            let newFailureCount = self.importResults.filter { $0.status == .failure }.count
            
            if endIndex < totalAssets {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.importBatch(assets: assets, totalAssets: totalAssets, currentIndex: endIndex, successCount: newSuccessCount, failureCount: newFailureCount, progressHandler: progressHandler, completionHandler: completionHandler)
                }
            } else {
                // All imports are completed
                progressHandler(1.0, newSuccessCount, newFailureCount)
                
                // Clear caches to ensure fresh data
                SQLiteManager.shared.invalidateCache()
                BirdCountCache.shared.clear()
                
                completionHandler(self.importResults)
                self.importResults = []
            }
        }
    }

    public func handleImportError(_ error: Error) {
        if let tuiError = error as? TuiImporterError {
            print("TuiImporterError: \(tuiError.rawValue) - \(tuiError.localizedDescription)")
        } else {
            print("Unknown error: \(error.localizedDescription)")
        }
    }
}
