import Photos
import UIKit
import CoreLocation
import ImageIO
import Foundation
import UniformTypeIdentifiers

class BulkImportHelper {
    static func importAsset(_ asset: PHAsset, completion: @escaping (Bool, String?, UIImage?) -> Void) {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let originalFileName = resources.first?.originalFilename else {
            BulkImportManager.shared.handleImportError(TuiImporterError.photoMetadataError)
            getThumbnail(for: asset) { thumbnail in
                completion(false, "Failed to get original file name", thumbnail)
            }
            return
        }

        guard asset.mediaType == .image else {
            BulkImportManager.shared.handleImportError(TuiImporterError.photoMetadataError)
            getThumbnail(for: asset) { thumbnail in
                completion(false, "Non-image asset", thumbnail)
            }
            return
        }
        
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        options.canHandleAdjustmentData = { _ in true }
        
        asset.requestContentEditingInput(with: options) { input, info in
            guard let input = input, let fullSizeImageURL = input.fullSizeImageURL else {
                BulkImportManager.shared.handleImportError(TuiImporterError.photoDataError)
                getThumbnail(for: asset) { thumbnail in
                    completion(false, "Failed to get full size image URL", thumbnail)
                }
                return
            }
            
            do {
                let imageData = try Data(contentsOf: fullSizeImageURL)
                // 使用原始文件名作为文件名前缀
                let fileNamePrefix = URL(fileURLWithPath: originalFileName).deletingPathExtension().lastPathComponent
                
                PhotoExtractor.extractAndSaveBulkPhotoInfo(asset: asset, imageData: imageData, fileNamePrefix: fileNamePrefix) { success, reason, thumbnail in
                    if success {
                        completion(true, nil, thumbnail)
                    } else {
                        BulkImportManager.shared.handleImportError(TuiImporterError.photoMetadataError)
                        completion(false, reason, thumbnail)
                    }
                }
            } catch {
                BulkImportManager.shared.handleImportError(TuiImporterError.photoDataError)
                getThumbnail(for: asset) { thumbnail in
                    completion(false, "Failed to read image data: \(error.localizedDescription)", thumbnail)
                }
            }
        }
    }

    static func getThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFit, options: options) { image, _ in
            completion(image)
        }
    }
}
