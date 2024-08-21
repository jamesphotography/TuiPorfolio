import Foundation
import UIKit

class PhotoSaver {
    static func saveBulkPhoto(_ photo: Photo, imageData: Data, completion: @escaping (Bool, Error?) -> Void) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = dateFormatter.date(from: photo.dateTimeOriginal) else {
            completion(false, ImportError.invalidDate)
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
            .appendingPathComponent(day)
        
        do {
            try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
            
            let originalFileName = "\(photo.id).jpg"
            let originalPath = directoryPath.appendingPathComponent(originalFileName)
            try imageData.write(to: originalPath)
            
            let thumbnail100 = ImportUtilities.generateThumbnail(from: imageData, size: CGSize(width: 100, height: 100))
            let thumbnail350 = ImportUtilities.generateThumbnail(from: imageData, size: CGSize(width: 350, height: 350))
            
            let thumbnail100Path = directoryPath.appendingPathComponent("\(photo.id)_thumb100.jpg")
            let thumbnail350Path = directoryPath.appendingPathComponent("\(photo.id)_thumb350.jpg")
            
            guard let thumbnail100Data = thumbnail100?.jpegData(compressionQuality: 0.8),
                  let thumbnail350Data = thumbnail350?.jpegData(compressionQuality: 0.8) else {
                completion(false, ImportError.failedToSaveThumbnail("Failed to generate thumbnail data"))
                return
            }
            
            try thumbnail100Data.write(to: thumbnail100Path)
            try thumbnail350Data.write(to: thumbnail350Path)
            
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
            
            if success {
                completion(true, nil)
            } else {
                completion(false, ImportError.failedToAddToDatabase)
            }
        } catch {
            completion(false, ImportError.failedToSaveImage(error.localizedDescription))
        }
    }
}
