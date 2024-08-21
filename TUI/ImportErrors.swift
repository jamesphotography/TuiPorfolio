import Foundation

public enum TuiImporterError: Int, Error {
    case unknown = 0
    case photoLibraryAccessDenied = 1
    case photoLibraryAccessRestricted = 2
    case photoLibraryAccessLimited = 3
    case photoLibraryAccessError = 4
    case photoMetadataError = 5
    case photoDataError = 6
    case appleAccountError = 7
    
    public var localizedDescription: String {
        switch self {
        case .unknown:
            return NSLocalizedString("Unknown error occurred", comment: "")
        case .photoLibraryAccessDenied:
            return NSLocalizedString("Access to photo library was denied", comment: "")
        case .photoLibraryAccessRestricted:
            return NSLocalizedString("Access to photo library is restricted", comment: "")
        case .photoLibraryAccessLimited:
            return NSLocalizedString("Access to photo library is limited", comment: "")
        case .photoLibraryAccessError:
            return NSLocalizedString("Error accessing photo library", comment: "")
        case .photoMetadataError:
            return NSLocalizedString("Error reading photo metadata", comment: "")
        case .photoDataError:
            return NSLocalizedString("Error reading photo data", comment: "")
        case .appleAccountError:
            return NSLocalizedString("Error with Apple account", comment: "")
        }
    }
}

public enum ImportError: Error {
    case nonImageAsset
    case failedToGetImageData
    case failedToCreatePhotoObject
    case photoAlreadyExists
    case failedToSaveImage(String)
    case failedToSaveThumbnail(String)
    case failedToAddToDatabase
    case invalidDate
    case geocodingFailed
    
    public var localizedDescription: String {
        switch self {
        case .nonImageAsset:
            return "The asset is not an image"
        case .failedToGetImageData:
            return "Failed to get image data"
        case .failedToCreatePhotoObject:
            return "Failed to create photo object"
        case .photoAlreadyExists:
            return "Photo already exists in the database"
        case .failedToSaveImage(let reason):
            return "Failed to save image: \(reason)"
        case .failedToSaveThumbnail(let reason):
            return "Failed to save thumbnail: \(reason)"
        case .failedToAddToDatabase:
            return "Failed to add photo to database"
        case .invalidDate:
            return "Invalid date format"
        case .geocodingFailed:
            return "Failed to geocode location"
        }
    }
}
