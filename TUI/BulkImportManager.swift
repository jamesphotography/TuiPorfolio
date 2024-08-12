import Photos
import UIKit
import CoreLocation

struct ImportResult: Identifiable {
    let id = UUID()
    let originalFileName: String
    let status: ImportStatus
    let reason: String?
    
    enum ImportStatus {
        case success
        case failure
    }
}

class BulkImportManager {
    static let shared = BulkImportManager()
    private init() {}
    
    private var importResults: [ImportResult] = []
    private let batchSize = 3
    
    func importPhotos(from album: PHAssetCollection, progressHandler: @escaping (Float, Int, Int) -> Void, completionHandler: @escaping ([ImportResult]) -> Void) {
        let assets = PHAsset.fetchAssets(in: album, options: nil)
        let totalAssets = assets.count
        
        importBatch(assets: assets, totalAssets: totalAssets, currentIndex: 0, successCount: 0, failureCount: 0, progressHandler: progressHandler) { results in
            completionHandler(results)
        }
    }
    
    private func importBatch(assets: PHFetchResult<PHAsset>, totalAssets: Int, currentIndex: Int, successCount: Int, failureCount: Int, progressHandler: @escaping (Float, Int, Int) -> Void, completionHandler: @escaping ([ImportResult]) -> Void) {
        let endIndex = min(currentIndex + batchSize, totalAssets)
        let group = DispatchGroup()
        
        for i in currentIndex..<endIndex {
            group.enter()
            let asset = assets[i]
            importAsset(asset) { success, reason in
                DispatchQueue.main.async {
                    if success {
                        let newSuccessCount = successCount + 1
                        progressHandler(Float(i + 1) / Float(totalAssets), newSuccessCount, failureCount)
                    } else {
                        let newFailureCount = failureCount + 1
                        progressHandler(Float(i + 1) / Float(totalAssets), successCount, newFailureCount)
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let newSuccessCount = self.importResults.filter { $0.status == .success }.count
            let newFailureCount = self.importResults.filter { $0.status == .failure }.count
            
            if endIndex < totalAssets {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.importBatch(assets: assets, totalAssets: totalAssets, currentIndex: endIndex, successCount: newSuccessCount, failureCount: newFailureCount, progressHandler: progressHandler, completionHandler: completionHandler)
                }
            } else {
                progressHandler(1.0, newSuccessCount, newFailureCount)
                completionHandler(self.importResults)
                self.importResults = []
            }
        }
    }
    
    private func importAsset(_ asset: PHAsset, completion: @escaping (Bool, String?) -> Void) {
        let resources = PHAssetResource.assetResources(for: asset)
        let originalFileName = resources.first?.originalFilename ?? "Unknown"
        
        guard asset.mediaType == .image else {
            self.importResults.append(ImportResult(originalFileName: originalFileName, status: .failure, reason: "Non-image asset"))
            completion(false, "Non-image asset")
            return
        }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
            if let error = info?[PHImageErrorKey] as? Error {
                self.importResults.append(ImportResult(originalFileName: originalFileName, status: .failure, reason: error.localizedDescription))
                completion(false, error.localizedDescription)
                return
            }
            
            guard let image = image, let data = image.jpegData(compressionQuality: 1.0) else {
                self.importResults.append(ImportResult(originalFileName: originalFileName, status: .failure, reason: "Failed to get image data"))
                completion(false, "Failed to get image data")
                return
            }
            
            self.extractAndSaveBulkPhotoInfo(asset: asset, imageData: data) { success, reason in
                if success {
                    self.importResults.append(ImportResult(originalFileName: originalFileName, status: .success, reason: nil))
                } else {
                    self.importResults.append(ImportResult(originalFileName: originalFileName, status: .failure, reason: reason))
                }
                completion(success, reason)
            }
        }
    }
    
    private func extractAndSaveBulkPhotoInfo(asset: PHAsset, imageData: Data, completion: @escaping (Bool, String?) -> Void) {
        let group = DispatchGroup()
        group.enter()
        
        var photo: Photo?
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        
        asset.requestContentEditingInput(with: options) { input, info in
            defer { group.leave() }
            guard let input = input, let fullSizeImageURL = input.fullSizeImageURL else {
                return
            }
            
            let id = UUID().uuidString
            var title = ""
            var cameraInfo = ""
            var lensInfo = ""
            var captureDate = ""
            var latitude = 0.0
            var longitude = 0.0
            var country = ""
            var area = ""
            var locality = ""
            var starRating = 0
            var exposureTime = 0.0
            var fNumber = 0.0
            var focalLenIn35mmFilm = 0.0
            var focalLength = 0.0
            var ISOSPEEDRatings = 0
            var altitude = 0.0
            var objectName = ""
            var caption = ""
            
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first {
                title = URL(fileURLWithPath: resource.originalFilename).deletingPathExtension().lastPathComponent
            }
            
            guard let ciImage = CIImage(contentsOf: fullSizeImageURL) else {
                return
            }
            
            let properties = ciImage.properties
            if let tiffDict = properties["{TIFF}"] as? [String: Any] {
                cameraInfo = tiffDict["Model"] as? String ?? ""
            }
            
            if let exifDict = properties["{Exif}"] as? [String: Any] {
                lensInfo = exifDict["LensModel"] as? String ?? ""
                
                if let dateTimeOriginal = exifDict["DateTimeOriginal"] as? String {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    if let date = dateFormatter.date(from: dateTimeOriginal) {
                        let displayFormatter = DateFormatter()
                        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        captureDate = displayFormatter.string(from: date)
                    }
                }
                
                exposureTime = exifDict["ExposureTime"] as? Double ?? 0.0
                fNumber = exifDict["FNumber"] as? Double ?? 0.0
                focalLenIn35mmFilm = exifDict["FocalLenIn35mmFilm"] as? Double ?? 0.0
                focalLength = exifDict["FocalLength"] as? Double ?? 0.0
                
                if let isoSpeedRatings = exifDict["ISOSpeedRatings"] as? [Int], !isoSpeedRatings.isEmpty {
                    ISOSPEEDRatings = isoSpeedRatings[0]
                } else if let isoSpeedRatings = exifDict["ISOSpeedRatings"] as? Int {
                    ISOSPEEDRatings = isoSpeedRatings
                }
            }
            
            if let exifAuxDict = properties["{ExifAux}"] as? [String: Any] {
                if let lensModel = exifAuxDict["LensModel"] as? String, lensInfo.isEmpty {
                    lensInfo = lensModel
                }
            }
            
            if let gpsDict = properties["{GPS}"] as? [String: Any] {
                if let latitudeRef = gpsDict["LatitudeRef"] as? String,
                   let longitudeRef = gpsDict["LongitudeRef"] as? String,
                   let latitudeValue = gpsDict["Latitude"] as? Double,
                   let longitudeValue = gpsDict["Longitude"] as? Double {
                    
                    latitude = latitudeRef == "S" ? -latitudeValue : latitudeValue
                    longitude = longitudeRef == "W" ? -longitudeValue : longitudeValue
                    
                    altitude = gpsDict["Altitude"] as? Double ?? 0.0
                    
                    group.enter()
                    self.geocodeLocation(latitude: latitude, longitude: longitude) { geocodedCountry, geocodedArea, geocodedLocality in
                        country = geocodedCountry
                        area = geocodedArea
                        locality = geocodedLocality
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            group.leave()
                        }
                    }
                }
            }
            
            if let iptcDict = properties["{IPTC}"] as? [String: Any] {
                starRating = iptcDict["StarRating"] as? Int ?? 0
                objectName = iptcDict["ObjectName"] as? String ?? ""
                caption = iptcDict["Caption/Abstract"] as? String ?? ""
            }
            
            if SQLiteManager.shared.isPhotoExists(captureDate: captureDate, fileNamePrefix: title) {
                completion(false, "Photo already exists")
                return
            }
            
            group.notify(queue: .main) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    photo = Photo(id: id, title: title, path: "", thumbnailPath100: "", thumbnailPath350: "",
                                  starRating: starRating, country: country, area: area, locality: locality,
                                  dateTimeOriginal: captureDate, addTimestamp: Date().ISO8601Format(),
                                  lensModel: lensInfo, model: cameraInfo, exposureTime: exposureTime,
                                  fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm,
                                  focalLength: focalLength, ISOSPEEDRatings: ISOSPEEDRatings,
                                  altitude: altitude, latitude: latitude, longitude: longitude,
                                  objectName: objectName, caption: caption)
                    
                    guard let photo = photo else {
                        completion(false, "Failed to create photo object")
                        return
                    }
                    self.saveBulkPhoto(photo, imageData: imageData) { success in
                        completion(success, success ? nil : "Failed to save photo")
                    }
                }
            }
        }
    }
    
    private func geocodeLocation(latitude: Double, longitude: Double, completion: @escaping (String, String, String) -> Void) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        func attemptGeocoding(for location: CLLocation, isRetry: Bool = false) {
            let locale = Locale(identifier: "en_US")
            geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { placemarks, error in
                if error != nil {
                    completion("Unknown Country", "Unknown Area", "Unknown Location")
                    return
                }
                
                if let placemark = placemarks?.first {
                    if let country = placemark.country, country != "Unknown" {
                        let area = placemark.administrativeArea ?? "Unknown Area"
                        let locality = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown Location"
                        completion(country, area, locality)
                    } else if !isRetry {
                        let reversedLocation = CLLocation(latitude: -latitude, longitude: longitude)
                        attemptGeocoding(for: reversedLocation, isRetry: true)
                    } else {
                        completion("Unknown Country", "Unknown Area", "Unknown Location")
                    }
                } else {
                    completion("Unknown Country", "Unknown Area", "Unknown Location")
                }
            }
        }
        
        attemptGeocoding(for: location)
    }
    
    private func saveBulkPhoto(_ photo: Photo, imageData: Data, completion: @escaping (Bool) -> Void) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = dateFormatter.date(from: photo.dateTimeOriginal) else {
            completion(false)
            return
        }
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let year = yearFormatter.string(from: date)
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        let month = monthFormatter.string(from: date)
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let day = dayFormatter.string(from: date)
        
        let directoryPath = documentsDirectory.appendingPathComponent("portfolio")
            .appendingPathComponent(year)
            .appendingPathComponent(month)
            .appendingPathComponent(day)  // 添加日期到路径中
        
        do {
            try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
            
            let originalFileName = "\(photo.id).jpg"
            let originalPath = directoryPath.appendingPathComponent(originalFileName)
            try imageData.write(to: originalPath)
            
            let thumbnail100 = generateThumbnail(from: imageData, size: CGSize(width: 100, height: 100))
            let thumbnail350 = generateThumbnail(from: imageData, size: CGSize(width: 350, height: 350))
            
            let thumbnail100Path = directoryPath.appendingPathComponent("\(photo.id)_thumb100.jpg")
            let thumbnail350Path = directoryPath.appendingPathComponent("\(photo.id)_thumb350.jpg")
            
            try thumbnail100?.jpegData(compressionQuality: 0.8)?.write(to: thumbnail100Path)
            try thumbnail350?.jpegData(compressionQuality: 0.8)?.write(to: thumbnail350Path)
            
            let updatedPhoto = Photo(
                id: photo.id,
                title: photo.title,
                path: originalPath.path.replacingOccurrences(of: documentsDirectory.path, with: ""),
                thumbnailPath100: thumbnail100Path.path.replacingOccurrences(of: documentsDirectory.path, with: ""),
                thumbnailPath350: thumbnail350Path.path.replacingOccurrences(of: documentsDirectory.path, with: ""),
                starRating: photo.starRating,
                country: photo.country,
                area: photo.area.isEmpty ? "Unknown Area" : photo.area,
                locality: photo.locality.isEmpty ? "Unknown Location" : photo.locality,
                dateTimeOriginal: photo.dateTimeOriginal,
                addTimestamp: photo.addTimestamp,
                lensModel: photo.lensModel,
                model: photo.model,
                exposureTime: photo.exposureTime,
                fNumber: photo.fNumber,
                focalLenIn35mmFilm: photo.focalLenIn35mmFilm,
                focalLength: photo.focalLength,
                ISOSPEEDRatings: photo.ISOSPEEDRatings,
                altitude: photo.altitude,
                latitude: photo.latitude,
                longitude: photo.longitude,
                objectName: photo.objectName,
                caption: photo.caption
            )
            
            let success = SQLiteManager.shared.addBulkPhoto(
                id: updatedPhoto.id,
                title: updatedPhoto.title,
                path: updatedPhoto.path,
                thumbnailPath100: updatedPhoto.thumbnailPath100,
                thumbnailPath350: updatedPhoto.thumbnailPath350,
                starRating: updatedPhoto.starRating,
                country: updatedPhoto.country,
                area: updatedPhoto.area,
                locality: updatedPhoto.locality,
                dateTimeOriginal: updatedPhoto.dateTimeOriginal,
                addTimestamp: updatedPhoto.addTimestamp,
                lensModel: updatedPhoto.lensModel,
                model: updatedPhoto.model,
                exposureTime: updatedPhoto.exposureTime,
                fNumber: updatedPhoto.fNumber,
                focalLenIn35mmFilm: updatedPhoto.focalLenIn35mmFilm,
                focalLength: updatedPhoto.focalLength,
                ISOSPEEDRatings: updatedPhoto.ISOSPEEDRatings,
                altitude: updatedPhoto.altitude,
                latitude: updatedPhoto.latitude,
                longitude: updatedPhoto.longitude,
                objectName: updatedPhoto.objectName,
                caption: updatedPhoto.caption
            )
            completion(success)
        } catch {
            completion(false)
        }
    }
    
    private func generateThumbnail(from imageData: Data, size: CGSize) -> UIImage? {
        guard let image = UIImage(data: imageData) else { return nil }
        
        let originalSize = image.size
        let widthRatio = size.width / originalSize.width
        let heightRatio = size.height / originalSize.height
        let scale = max(widthRatio, heightRatio)
        
        let scaledWidth = originalSize.width * scale
        let scaledHeight = originalSize.height * scale
        let scaledSize = CGSize(width: scaledWidth, height: scaledHeight)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let origin = CGPoint(
                x: (size.width - scaledWidth) / 2.0,
                y: (size.height - scaledHeight) / 2.0
            )
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}
