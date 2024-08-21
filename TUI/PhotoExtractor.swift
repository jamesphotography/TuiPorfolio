import Photos
import UIKit
import CoreLocation
import ImageIO
import Foundation
import UniformTypeIdentifiers
import MobileCoreServices

class PhotoExtractor {
    static let geocodeQueue = DispatchQueue(label: "com.app.geocodeQueue", attributes: .concurrent)
    static var geocodeOperations = 0
    static let geocodeSemaphore = DispatchSemaphore(value: 1)
    
    static func extractAndSaveBulkPhotoInfo(asset: PHAsset, imageData: Data, fileNamePrefix: String, completion: @escaping (Bool, String?, UIImage?) -> Void) {
        let uuid = UUID().uuidString
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            completion(false, "Failed to create image source", nil)
            return
        }
        
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            completion(false, "No metadata found", nil)
            return
        }
        
        let exifDict = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiffDict = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let gpsDict = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
        let iptcDict = metadata[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        
        guard let captureDate = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String, !captureDate.isEmpty else {
            getThumbnail(from: imageData) { thumbnail in
                completion(false, "Photo has no capture date", thumbnail)
            }
            return
        }
        
        let formattedCaptureDate = formatDate(captureDate)
        
        // 处理文件名作为 title
        let title = URL(string: fileNamePrefix)?.deletingPathExtension().lastPathComponent ?? fileNamePrefix
        print("Processing photo with title: \(title)")  // 添加日志
        
        if SQLiteManager.shared.isPhotoExists(captureDate: formattedCaptureDate, fileNamePrefix: title) {
            getThumbnail(from: imageData) { thumbnail in
                completion(false, "Photo already exists", thumbnail)
            }
            return
        }
        
        let cameraInfo = tiffDict[kCGImagePropertyTIFFModel as String] as? String ?? ""
        let lensInfo = exifDict[kCGImagePropertyExifLensModel as String] as? String ?? ""
        let exposureTime = exifDict[kCGImagePropertyExifExposureTime as String] as? Double ?? 0.0
        let fNumber = exifDict[kCGImagePropertyExifFNumber as String] as? Double ?? 0.0
        let focalLenIn35mmFilm = exifDict[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Double ?? 0.0
        let focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double ?? 0.0
        let isoSpeedRatings: Int
        if let isoArray = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let iso = isoArray.first {
            isoSpeedRatings = iso
        } else {
            isoSpeedRatings = 0
        }
        let objectName = iptcDict[kCGImagePropertyIPTCObjectName as String] as? String ?? ""
        let caption = iptcDict[kCGImagePropertyIPTCCaptionAbstract as String] as? String ?? ""
        
        let starRating = iptcDict[kCGImagePropertyIPTCStarRating as String] as? Int ?? 0

        var latitude: Double = 0.0
        var longitude: Double = 0.0
        var altitude: Double = 0.0

        if let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String,
           let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String,
           let latitudeValue = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
           let longitudeValue = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double {
            
            latitude = latitudeRef == "S" ? -latitudeValue : latitudeValue
            longitude = longitudeRef == "W" ? -longitudeValue : longitudeValue
        }

        if let altitudeValue = gpsDict[kCGImagePropertyGPSAltitude as String] as? Double {
            altitude = altitudeValue
        }
        
        let date = dateFormatter.date(from: captureDate) ?? Date()
        let year = Calendar.current.component(.year, from: date)
        let month = String(format: "%04d-%02d", year, Calendar.current.component(.month, from: date))
        let day = String(format: "%04d-%02d-%02d", year, Calendar.current.component(.month, from: date), Calendar.current.component(.day, from: date))
        
        let portfolioDirectory = getDocumentsDirectory()
            .appendingPathComponent("portfolio")
            .appendingPathComponent(String(year))
            .appendingPathComponent(month)
            .appendingPathComponent(day)
        
        do {
            try FileManager.default.createDirectory(at: portfolioDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            getThumbnail(from: imageData) { thumbnail in
                completion(false, "Failed to create portfolio directory: \(error)", thumbnail)
            }
            return
        }
        
        let fileName = "\(uuid).jpg"
        let fileURL = portfolioDirectory.appendingPathComponent(fileName)
        
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            getThumbnail(from: imageData) { thumbnail in
                completion(false, "Failed to create image destination", thumbnail)
            }
            return
        }
        
        CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            guard let uiImage = UIImage(data: imageData) else {
                getThumbnail(from: imageData) { thumbnail in
                    completion(false, "Failed to create UIImage from data", thumbnail)
                }
                return
            }
            
            let thumbnail100 = generateThumbnail(for: uiImage, size: CGSize(width: 100, height: 100))
            let thumbnail350 = generateThumbnail(for: uiImage, size: CGSize(width: 350, height: 350))
            
            let thumbnail100Name = "\(uuid)_thumb100.jpg"
            let thumbnail350Name = "\(uuid)_thumb350.jpg"
            let thumbnail100Path = portfolioDirectory.appendingPathComponent(thumbnail100Name)
            let thumbnail350Path = portfolioDirectory.appendingPathComponent(thumbnail350Name)
            
            do {
                try thumbnail100?.jpegData(compressionQuality: 0.8)?.write(to: thumbnail100Path)
                try thumbnail350?.jpegData(compressionQuality: 0.8)?.write(to: thumbnail350Path)
            } catch {
                completion(false, "Failed to save thumbnails: \(error)", thumbnail100)
                return
            }
            
            let relativePath = fileURL.path.replacingOccurrences(of: getDocumentsDirectory().path, with: "")
            let relativeThumbnail100Path = thumbnail100Path.path.replacingOccurrences(of: getDocumentsDirectory().path, with: "")
            let relativeThumbnail350Path = thumbnail350Path.path.replacingOccurrences(of: getDocumentsDirectory().path, with: "")
            
            geocodeLocation(latitude: latitude, longitude: longitude) { country, area, locality in
                print("Geocoding result - Country: \(country), Area: \(area), Locality: \(locality)")
                
                let addTimestamp = Date().ISO8601Format()
                
                print("Saving photo with title: \(title)")  // 添加日志
                
                let success = SQLiteManager.shared.addBulkPhoto(
                    id: uuid,
                    title: title,
                    path: relativePath,
                    thumbnailPath100: relativeThumbnail100Path,
                    thumbnailPath350: relativeThumbnail350Path,
                    starRating: starRating,
                    country: country,
                    area: area,
                    locality: locality,
                    dateTimeOriginal: formattedCaptureDate,
                    addTimestamp: addTimestamp,
                    lensModel: lensInfo,
                    model: cameraInfo,
                    exposureTime: exposureTime,
                    fNumber: fNumber,
                    focalLenIn35mmFilm: focalLenIn35mmFilm,
                    focalLength: focalLength,
                    ISOSPEEDRatings: isoSpeedRatings,
                    altitude: altitude,
                    latitude: latitude,
                    longitude: longitude,
                    objectName: objectName,
                    caption: caption
                )
                
                if success {
                    print("Successfully saved photo to SQLite - ID: \(uuid)")
                    completion(true, nil, thumbnail100)
                } else {
                    print("Failed to save photo to SQLite - ID: \(uuid)")
                    completion(false, "Failed to save photo to SQLite", thumbnail100)
                }
            }
        } else {
            getThumbnail(from: imageData) { thumbnail in
                completion(false, "Failed to save image", thumbnail)
            }
        }
    }
    
    private static func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
    
    private static func generateThumbnail(for image: UIImage, size: CGSize) -> UIImage? {
        let aspectWidth = size.width / image.size.width
        let aspectHeight = size.height / image.size.height
        let aspectRatio = max(aspectWidth, aspectHeight)
        
        let newSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { _ in
            let x = (newSize.width - size.width) / 2
            let y = (newSize.height - size.height) / 2
            image.draw(in: CGRect(x: -x, y: -y, width: newSize.width, height: newSize.height))
        }
    }
    
    private static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private static func geocodeLocation(latitude: Double, longitude: Double, completion: @escaping (String, String, String) -> Void) {
        geocodeQueue.async {
            geocodeSemaphore.wait()
            geocodeOperations += 1
            print("Starting geocode operation. Current operations: \(geocodeOperations)")
            
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let geocoder = CLGeocoder()
            
            let locale = Locale(identifier: "en_US")
            geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { placemarks, error in
                defer {
                    geocodeOperations -= 1
                    print("Finished geocode operation. Remaining operations: \(geocodeOperations)")
                    geocodeSemaphore.signal()
                }
                
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                }
                
                if let placemark = placemarks?.first {
                    let country = placemark.country ?? "Unknown Country"
                    let area = placemark.administrativeArea ?? "Unknown Area"
                    let locality = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown Location"
                    print("Geocoding success - Country: \(country), Area: \(area), Locality: \(locality)")
                    completion(country, area, locality)
                } else {
                    print("No placemark found, using default values")
                    completion("Unknown Country", "Unknown Area", "Unknown Location")
                }
            }
            
            // 添加延迟以确保不超过 Apple 的 API 限制
            Thread.sleep(forTimeInterval: 1.2) // 确保每次调用之间至少有 1.2 秒的间隔
        }
    }
    
    private static func getThumbnail(from imageData: Data, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = UIImage(data: imageData) {
                let thumbnail = generateThumbnail(for: image, size: CGSize(width: 100, height: 100))
                DispatchQueue.main.async {
                    completion(thumbnail)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
