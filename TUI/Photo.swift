import Foundation

struct Photo: Identifiable, Hashable {
    let id: String
    let title: String
    let path: String
    let thumbnailPath100: String
    let thumbnailPath350: String
    let starRating: Int
    let country: String
    let area: String
    let locality: String
    let dateTimeOriginal: String
    let addTimestamp: String
    let lensModel: String
    let model: String
    let exposureTime: Double
    let fNumber: Double
    let focalLenIn35mmFilm: Double
    let focalLength: Double
    let ISOSPEEDRatings: Int
    let altitude: Double
    let latitude: Double
    let longitude: Double
    let objectName: String
    let caption: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Photo, rhs: Photo) -> Bool {
        lhs.id == rhs.id
    }
}


