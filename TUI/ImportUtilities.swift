import UIKit
import CoreLocation

class ImportUtilities {
    static func generateThumbnail(from imageData: Data, size: CGSize) -> UIImage? {
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
    
    static func geocodeLocation(latitude: Double, longitude: Double, completion: @escaping (Result<(String, String, String), Error>) -> Void) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        let locale = Locale(identifier: "en_US")
        geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { placemarks, error in
            if error != nil {
                completion(.failure(ImportError.geocodingFailed))
                return
            }
            
            if let placemark = placemarks?.first {
                let country = placemark.country ?? "Unknown Country"
                let area = placemark.administrativeArea ?? "Unknown Area"
                let locality = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown Location"
                completion(.success((country, area, locality)))
            } else {
                completion(.failure(ImportError.geocodingFailed))
            }
        }
    }
}
