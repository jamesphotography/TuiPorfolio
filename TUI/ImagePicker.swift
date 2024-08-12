import SwiftUI
import PhotosUI
import UIKit
import CoreLocation

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var imageName: String
    @Binding var cameraInfo: String
    @Binding var lensInfo: String
    @Binding var captureDate: String
    @Binding var latitude: String
    @Binding var longitude: String
    @Binding var country: String
    @Binding var area: String
    @Binding var locality: String
    @Binding var starRating: Int
    @Binding var exposureTime: Double
    @Binding var fNumber: Double
    @Binding var focalLenIn35mmFilm: Double
    @Binding var focalLength: Double
    @Binding var ISOSPEEDRatings: Int
    @Binding var altitude: Double
    @Binding var objectName: String
    @Binding var caption: String
    @Environment(\.presentationMode) var presentationMode
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                print("No image selected")
                return
            }
            
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
            
            if result.itemProvider.hasItemConformingToTypeIdentifier("public.image") {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.image") { (url, error) in
                    guard let url = url else {
                        print("Unable to get file URL")
                        return
                    }
                    
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let destinationURL = tempDirectory.appendingPathComponent(url.lastPathComponent)
                    
                    do {
                        // 如果目标文件已存在，先删除它
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        
                        // 使用文件协调器来复制文件
                        let coordinator = NSFileCoordinator()
                        var coordError: NSError?
                        coordinator.coordinate(readingItemAt: url, options: .immediatelyAvailableMetadataOnly, error: &coordError) { (newURL) in
                            do {
                                try FileManager.default.copyItem(at: newURL, to: destinationURL)
//                                print("File successfully copied to tmp directory: \(destinationURL)")
                                
                                // 读取文件数据并提取EXIF信息
                                let data = try Data(contentsOf: destinationURL)
                                DispatchQueue.main.async {
                                    self.extractExifInfo(from: data)
                                    self.parent.imageName = destinationURL.lastPathComponent
                                }
                            } catch {
                                print("Failed to copy file: \(error.localizedDescription)")
                            }
                        }
                        
                        if let error = coordError {
                            print("Coordination failed: \(error)")
                        }
                    } catch {
                        print("Failed to handle file: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        func extractExifInfo(from imageData: Data) {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return }
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return }
            
            
            if let tiffDict = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                if let camera = tiffDict[kCGImagePropertyTIFFModel] as? String {
                    self.parent.cameraInfo = camera
                }
            }
            
            if let exifDict = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                if let lens = exifDict[kCGImagePropertyExifLensModel] as? String {
                    self.parent.lensInfo = lens
                }
                if let dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal] as? String {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    if let date = dateFormatter.date(from: dateTimeOriginal) {
                        let displayFormatter = DateFormatter()
                        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        self.parent.captureDate = displayFormatter.string(from: date)
                    } else {
                        self.parent.captureDate = "Unknown date"
                    }
                }
                if let exposureTime = exifDict[kCGImagePropertyExifExposureTime] as? Double {
                    self.parent.exposureTime = exposureTime
                }
                if let fNumber = exifDict[kCGImagePropertyExifFNumber] as? Double {
                    self.parent.fNumber = fNumber
                }
                if let focalLenIn35mmFilm = exifDict[kCGImagePropertyExifFocalLenIn35mmFilm] as? Double {
                    self.parent.focalLenIn35mmFilm = focalLenIn35mmFilm
                }
                if let focalLength = exifDict[kCGImagePropertyExifFocalLength] as? Double {
                    self.parent.focalLength = focalLength
                }
                if let isoSpeedRatings = exifDict[kCGImagePropertyExifISOSpeedRatings] as? [Int], let iso = isoSpeedRatings.first {
                    self.parent.ISOSPEEDRatings = iso
                }
            }
            
            if let iptcDict = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] {
                if let starRating = iptcDict[kCGImagePropertyIPTCStarRating] as? Int {
                    self.parent.starRating = starRating
                }
                if let objectName = iptcDict[kCGImagePropertyIPTCObjectName] as? String {
                    self.parent.objectName = objectName
                }
                if let caption = iptcDict[kCGImagePropertyIPTCCaptionAbstract] as? String {
                    self.parent.caption = caption
                }
            }
            
            if let exifAuxDict = properties[kCGImagePropertyExifAuxDictionary] as? [CFString: Any] {
                if let lensModel = exifAuxDict[kCGImagePropertyExifAuxLensModel] as? String {
                    // 如果 lensInfo 为空，使用 lensModel 代替
                    if self.parent.lensInfo.isEmpty {
                        self.parent.lensInfo = lensModel
                    }
                }
            }
            
            // 更新 GPS 信息提取和地理编码部分
            if let gpsDict = properties[kCGImagePropertyGPSDictionary] as? [String: Any] {
                if let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String,
                   let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String,
                   let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
                   let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double {
                    
                    let adjustedLatitude = latitudeRef == "S" ? -latitude : latitude
                    let adjustedLongitude = longitudeRef == "W" ? -longitude : longitude
                    
                    self.parent.latitude = String(format: "%.6f", adjustedLatitude)
                    self.parent.longitude = String(format: "%.6f", adjustedLongitude)
                    
//                    print("Extracted Latitude: \(adjustedLatitude) with ref: \(latitudeRef)")
//                    print("Extracted Longitude: \(adjustedLongitude) with ref: \(longitudeRef)")
                    
                    // Altitude extraction
                    if let altitude = gpsDict[kCGImagePropertyGPSAltitude as String] as? Double {
                        self.parent.altitude = altitude
                    }
                    
                    // 使用新的地理编码方法
                    geocodeLocation(latitude: adjustedLatitude, longitude: adjustedLongitude)
                }
            }
        }
        
        // 转换GPS坐标为度数格式
        func convertToDegrees(value: [NSNumber]) -> Double {
            let d = Double(truncating: value[0])
            let m = Double(truncating: value[1])
            let s = Double(truncating: value[2])
            return d + (m / 60.0) + (s / 3600.0)
        }
        
        func geocodeLocation(latitude: Double, longitude: Double) {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let geocoder = CLGeocoder()
            
            let locale = Locale(identifier: "en_US")
            geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { placemarks, error in
                if let error = error {
                    self.handleGeocodingFailure()
                    return
                }
                
                if let placemark = placemarks?.first {
                    self.parent.country = placemark.country ?? "Unknown country"
                    self.parent.area = placemark.administrativeArea ?? "Unknown area"
                    self.parent.locality = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown locality"
                } else {
                    self.handleGeocodingFailure()
                }
            }
        }
        
        private func handleGeocodingFailure() {
            self.parent.country = "Unknown country"
            self.parent.area = "Unknown area"
            self.parent.locality = "Unknown locality"
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}
