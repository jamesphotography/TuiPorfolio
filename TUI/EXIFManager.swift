import SwiftUI

class EXIFManager {
    static let shared = EXIFManager()
    
    private init() {}
    
    func copyEXIFInfo(for photo: Photo) -> String {
        var exifInfo = """
        \(NSLocalizedString("Date Taken", comment: "EXIF info label")): \(formatDate(photo.dateTimeOriginal))
        \(NSLocalizedString("Camera Info", comment: "EXIF info label")): \(formatCameraInfo(photo: photo))
        \(NSLocalizedString("Exposure Info", comment: "EXIF info label")): \(exposureInfo(photo: photo))
        """
        
        if !photo.objectName.isEmpty {
            exifInfo += "\n\(NSLocalizedString("Species Name", comment: "EXIF info label")): \(photo.objectName)"
        }
        
        if !photo.caption.isEmpty {
            exifInfo += "\n\(NSLocalizedString("Description", comment: "EXIF info label")): \(photo.caption)"
        }
        
        if photo.latitude != 0 && photo.longitude != 0 {
            exifInfo += "\n\(NSLocalizedString("Location Info", comment: "EXIF info label")): \(locationInfoWithAltitude(photo: photo))"
        }
        
        return exifInfo
    }
    
    public func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
    
    public func formatCameraInfo(photo: Photo) -> String {
        let cameraModel = UserDefaults.standard.bool(forKey: "omitCameraBrand") ? removeBrandName(from: photo.model) : photo.model
        let lensModel = UserDefaults.standard.bool(forKey: "omitCameraBrand") ? removeBrandName(from: photo.lensModel) : photo.lensModel
        return String(format: NSLocalizedString("%@ (%@)", comment: "Camera and lens model format"), cameraModel, lensModel)
    }
    
    public func exposureInfo(photo: Photo) -> String {
        return String(format: NSLocalizedString("%.1fmm · f/%.1f · %@s · ISO%d", comment: "Exposure info format"),
                      photo.focalLength, photo.fNumber, formatExposureTime(photo.exposureTime), photo.ISOSPEEDRatings)
    }
    
    public func formatExposureTime(_ exposureTime: Double) -> String {
        if exposureTime >= 1 {
            return String(format: "%.1f", exposureTime)
        } else if exposureTime > 0 {
            let denominator = Int(round(1 / exposureTime))
            return String(format: NSLocalizedString("1/%d", comment: "Exposure time format for fractions of a second"), denominator)
        } else {
            return "0"
        }
    }
    
    public func locationInfoWithAltitude(photo: Photo) -> String {
        var info = ""
        if !photo.locality.isEmpty { info += photo.locality }
        if !photo.area.isEmpty {
            if !info.isEmpty { info += ", " }
            info += photo.area
        }
        if !photo.country.isEmpty {
            if !info.isEmpty { info += ", " }
            info += photo.country
        }
        if photo.altitude > 0 {
            if !info.isEmpty { info += " • " }
            info += String(format: NSLocalizedString("Altitude: %dm", comment: "Altitude info format"), Int(photo.altitude))
        }
        return info
    }
    
    public func removeBrandName(from model: String) -> String {
        let brandNames = ["Nikon", "Canon", "Sony", "Fujifilm", "Panasonic", "Olympus", "Leica", "Hasselblad", "Pentax", "Sigma", "Tamron", "Zeiss", "Nikkor", "Apple"]
        var result = model
        
        for brand in brandNames {
            if result.lowercased().contains(brand.lowercased()) {
                result = result.replacingOccurrences(of: brand, with: "", options: [.caseInsensitive, .anchored])
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        return result
    }
}
