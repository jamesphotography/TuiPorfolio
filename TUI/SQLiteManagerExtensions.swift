import SQLite3
import Foundation

extension SQLiteManager {
  

    
    func getPhotosByCountry(country: String, page: Int, itemsPerPage: Int) -> [Photo] {
        let offset = (page - 1) * itemsPerPage
        let queryStatementString = """
            SELECT * FROM Photos WHERE Country = ? LIMIT ? OFFSET ?;
            """
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (country as NSString).utf8String, -1, nil)
            sqlite3_bind_int(queryStatement, 2, Int32(itemsPerPage))
            sqlite3_bind_int(queryStatement, 3, Int32(offset))
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = String(describing: String(cString: sqlite3_column_text(queryStatement, 0)))
                let title = String(describing: String(cString: sqlite3_column_text(queryStatement, 1)))
                let path = String(describing: String(cString: sqlite3_column_text(queryStatement, 2)))
                let thumbnailPath100 = String(describing: String(cString: sqlite3_column_text(queryStatement, 3)))
                let thumbnailPath350 = String(describing: String(cString: sqlite3_column_text(queryStatement, 4)))
                let starRating = sqlite3_column_int(queryStatement, 5)
                let country = String(describing: String(cString: sqlite3_column_text(queryStatement, 6)))
                let area = String(describing: String(cString: sqlite3_column_text(queryStatement, 7)))
                let locality = String(describing: String(cString: sqlite3_column_text(queryStatement, 8)))
                let dateTimeOriginal = String(describing: String(cString: sqlite3_column_text(queryStatement, 9)))
                let addTimestamp = String(describing: String(cString: sqlite3_column_text(queryStatement, 10)))
                let lensModel = String(describing: String(cString: sqlite3_column_text(queryStatement, 11)))
                let model = String(describing: String(cString: sqlite3_column_text(queryStatement, 12)))
                let exposureTime = sqlite3_column_double(queryStatement, 13)
                let fNumber = sqlite3_column_double(queryStatement, 14)
                let focalLenIn35mmFilm = sqlite3_column_double(queryStatement, 15)
                let focalLength = sqlite3_column_double(queryStatement, 16)
                let ISOSPEEDRatings = sqlite3_column_int(queryStatement, 17)
                let altitude = sqlite3_column_double(queryStatement, 18)
                let latitude = sqlite3_column_double(queryStatement, 19)
                let longitude = sqlite3_column_double(queryStatement, 20)
                let objectName = String(describing: String(cString: sqlite3_column_text(queryStatement, 21)))
                let caption = String(describing: String(cString: sqlite3_column_text(queryStatement, 22)))
                
                photos.append(Photo(id: id, title: title, path: path, thumbnailPath100: thumbnailPath100, thumbnailPath350: thumbnailPath350, starRating: Int(starRating), country: country, area: area, locality: locality, dateTimeOriginal: dateTimeOriginal, addTimestamp: addTimestamp, lensModel: lensModel, model: model, exposureTime: exposureTime, fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm, focalLength: focalLength, ISOSPEEDRatings: Int(ISOSPEEDRatings), altitude: altitude, latitude: latitude, longitude: longitude, objectName: objectName, caption: caption))
            }
        } else {
            print("SELECT statement could not be prepared.")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }
    
    func getPhotosByCamera(_ cameraModel: String) -> [Photo] {
        let queryStatementString = """
            SELECT * FROM Photos
            WHERE Model = ?
            ORDER BY DateTimeOriginal DESC;
            """
        
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (cameraModel as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = String(describing: String(cString: sqlite3_column_text(queryStatement, 0)))
                let title = String(describing: String(cString: sqlite3_column_text(queryStatement, 1)))
                let path = String(describing: String(cString: sqlite3_column_text(queryStatement, 2)))
                let thumbnailPath100 = String(describing: String(cString: sqlite3_column_text(queryStatement, 3)))
                let thumbnailPath350 = String(describing: String(cString: sqlite3_column_text(queryStatement, 4)))
                let starRating = sqlite3_column_int(queryStatement, 5)
                let country = String(describing: String(cString: sqlite3_column_text(queryStatement, 6)))
                let area = String(describing: String(cString: sqlite3_column_text(queryStatement, 7)))
                let locality = String(describing: String(cString: sqlite3_column_text(queryStatement, 8)))
                let dateTimeOriginal = String(describing: String(cString: sqlite3_column_text(queryStatement, 9)))
                let addTimestamp = String(describing: String(cString: sqlite3_column_text(queryStatement, 10)))
                let lensModel = String(describing: String(cString: sqlite3_column_text(queryStatement, 11)))
                let model = String(describing: String(cString: sqlite3_column_text(queryStatement, 12)))
                let exposureTime = sqlite3_column_double(queryStatement, 13)
                let fNumber = sqlite3_column_double(queryStatement, 14)
                let focalLenIn35mmFilm = sqlite3_column_double(queryStatement, 15)
                let focalLength = sqlite3_column_double(queryStatement, 16)
                let ISOSPEEDRatings = sqlite3_column_int(queryStatement, 17)
                let altitude = sqlite3_column_double(queryStatement, 18)
                let latitude = sqlite3_column_double(queryStatement, 19)
                let longitude = sqlite3_column_double(queryStatement, 20)
                let objectName = String(describing: String(cString: sqlite3_column_text(queryStatement, 21)))
                let caption = String(describing: String(cString: sqlite3_column_text(queryStatement, 22)))
                
                photos.append(Photo(id: id, title: title, path: path, thumbnailPath100: thumbnailPath100, thumbnailPath350: thumbnailPath350, starRating: Int(starRating), country: country, area: area, locality: locality, dateTimeOriginal: dateTimeOriginal, addTimestamp: addTimestamp, lensModel: lensModel, model: model, exposureTime: exposureTime, fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm, focalLength: focalLength, ISOSPEEDRatings: Int(ISOSPEEDRatings), altitude: altitude, latitude: latitude, longitude: longitude, objectName: objectName, caption: caption))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }
    
    func getLensInfo() -> [(String, Int, String)] {
        let queryStatementString = """
            SELECT LensModel, COUNT(*) as Count, MAX(DateTimeOriginal) as LatestPhoto
            FROM Photos
            WHERE LensModel IS NOT NULL AND LensModel != ''
            GROUP BY LensModel
            ORDER BY LatestPhoto DESC;
            """
        
        var queryStatement: OpaquePointer?
        var results: [(String, Int, String)] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let lensModel = String(cString: sqlite3_column_text(queryStatement, 0))
                let count = Int(sqlite3_column_int(queryStatement, 1))
                let earliestPhoto = String(cString: sqlite3_column_text(queryStatement, 2))
                results.append((lensModel, count, earliestPhoto))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        return results
    }
    
    func getLatestPhotoInfoForBirds() -> [(String, String)] {
        let queryStatementString = """
            SELECT ObjectName, ThumbnailPath100
            FROM Photos
            WHERE (ObjectName, DateTimeOriginal) IN (
                SELECT ObjectName, MAX(DateTimeOriginal)
                FROM Photos
                WHERE ObjectName IS NOT NULL AND ObjectName != ''
                GROUP BY ObjectName
            )
            ORDER BY DateTimeOriginal DESC;
            """
        
        var queryStatement: OpaquePointer?
        var results: [(String, String)] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let objectName = String(cString: sqlite3_column_text(queryStatement, 0))
                let thumbnailPath = String(cString: sqlite3_column_text(queryStatement, 1))
                results.append((objectName, thumbnailPath))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        return results
    }
    
    func getPhotosByLens(_ lensModel: String) -> [Photo] {
        let queryStatementString = """
            SELECT * FROM Photos
            WHERE LensModel = ?
            ORDER BY DateTimeOriginal DESC;
            """
        
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (lensModel as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = String(describing: String(cString: sqlite3_column_text(queryStatement, 0)))
                let title = String(describing: String(cString: sqlite3_column_text(queryStatement, 1)))
                let path = String(describing: String(cString: sqlite3_column_text(queryStatement, 2)))
                let thumbnailPath100 = String(describing: String(cString: sqlite3_column_text(queryStatement, 3)))
                let thumbnailPath350 = String(describing: String(cString: sqlite3_column_text(queryStatement, 4)))
                let starRating = sqlite3_column_int(queryStatement, 5)
                let country = String(describing: String(cString: sqlite3_column_text(queryStatement, 6)))
                let area = String(describing: String(cString: sqlite3_column_text(queryStatement, 7)))
                let locality = String(describing: String(cString: sqlite3_column_text(queryStatement, 8)))
                let dateTimeOriginal = String(describing: String(cString: sqlite3_column_text(queryStatement, 9)))
                let addTimestamp = String(describing: String(cString: sqlite3_column_text(queryStatement, 10)))
                let lensModel = String(describing: String(cString: sqlite3_column_text(queryStatement, 11)))
                let model = String(describing: String(cString: sqlite3_column_text(queryStatement, 12)))
                let exposureTime = sqlite3_column_double(queryStatement, 13)
                let fNumber = sqlite3_column_double(queryStatement, 14)
                let focalLenIn35mmFilm = sqlite3_column_double(queryStatement, 15)
                let focalLength = sqlite3_column_double(queryStatement, 16)
                let ISOSPEEDRatings = sqlite3_column_int(queryStatement, 17)
                let altitude = sqlite3_column_double(queryStatement, 18)
                let latitude = sqlite3_column_double(queryStatement, 19)
                let longitude = sqlite3_column_double(queryStatement, 20)
                let objectName = String(describing: String(cString: sqlite3_column_text(queryStatement, 21)))
                let caption = String(describing: String(cString: sqlite3_column_text(queryStatement, 22)))
                
                photos.append(Photo(id: id, title: title, path: path, thumbnailPath100: thumbnailPath100, thumbnailPath350: thumbnailPath350, starRating: Int(starRating), country: country, area: area, locality: locality, dateTimeOriginal: dateTimeOriginal, addTimestamp: addTimestamp, lensModel: lensModel, model: model, exposureTime: exposureTime, fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm, focalLength: focalLength, ISOSPEEDRatings: Int(ISOSPEEDRatings), altitude: altitude, latitude: latitude, longitude: longitude, objectName: objectName, caption: caption))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }

    func addBulkPhoto(id: String, title: String, path: String, thumbnailPath100: String, thumbnailPath350: String, starRating: Int, country: String, area: String, locality: String, dateTimeOriginal: String, addTimestamp: String, lensModel: String, model: String, exposureTime: Double, fNumber: Double, focalLenIn35mmFilm: Double, focalLength: Double, ISOSPEEDRatings: Int, altitude: Double, latitude: Double, longitude: Double, objectName: String, caption: String) -> Bool {
        
        // 将 addTimestamp 转换为 "yyyy-MM-dd HH:mm:ss" 格式
        let formattedAddTimestamp: String
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = dateFormatter.date(from: addTimestamp) {
            formattedAddTimestamp = dateFormatter.string(from: date)
        } else {
            // 如果转换失败，尝试其他常见格式
            let possibleFormats = ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd"]
            var parsedDate: Date?
            for format in possibleFormats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: addTimestamp) {
                    parsedDate = date
                    break
                }
            }
            
            if let parsedDate = parsedDate {
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formattedAddTimestamp = dateFormatter.string(from: parsedDate)
            } else {
                // 如果所有尝试都失败，使用当前时间
                formattedAddTimestamp = dateFormatter.string(from: Date())
            }
        }

        let insertStatementString = """
        INSERT INTO Photos (Id, Title, Path, ThumbnailPath100, ThumbnailPath350, StarRating, Country, Area, Locality, DateTimeOriginal, AddTimestamp, LensModel, Model, ExposureTime, FNumber, FocalLenIn35mmFilm, FocalLength, ISOSPEEDRatings, Altitude, Latitude, Longitude, ObjectName, Caption)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var insertStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, (path as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 4, (thumbnailPath100 as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 5, (thumbnailPath350 as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 6, Int32(starRating))
            sqlite3_bind_text(insertStatement, 7, (country as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 8, (area as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 9, (locality as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 10, (dateTimeOriginal as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 11, (formattedAddTimestamp as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 12, (lensModel as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 13, (model as NSString).utf8String, -1, nil)
            sqlite3_bind_double(insertStatement, 14, exposureTime)
            sqlite3_bind_double(insertStatement, 15, fNumber)
            sqlite3_bind_double(insertStatement, 16, focalLenIn35mmFilm)
            sqlite3_bind_double(insertStatement, 17, focalLength)
            sqlite3_bind_int(insertStatement, 18, Int32(ISOSPEEDRatings))
            sqlite3_bind_double(insertStatement, 19, altitude)
            sqlite3_bind_double(insertStatement, 20, latitude)
            sqlite3_bind_double(insertStatement, 21, longitude)
            sqlite3_bind_text(insertStatement, 22, (objectName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 23, (caption as NSString).utf8String, -1, nil)
                       
            let result = sqlite3_step(insertStatement)
            if result == SQLITE_DONE {
                sqlite3_finalize(insertStatement)
                return true
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("Could not insert bulk photo. SQLite error: \(errorMessage)")
                print("Failed SQL: \(insertStatementString)")
                print("Values: id=\(id), title=\(title), path=\(path), thumbnailPath100=\(thumbnailPath100), thumbnailPath350=\(thumbnailPath350), starRating=\(starRating), country=\(country), area=\(area), locality=\(locality), dateTimeOriginal=\(dateTimeOriginal), addTimestamp=\(formattedAddTimestamp), lensModel=\(lensModel), model=\(model), exposureTime=\(exposureTime), fNumber=\(fNumber), focalLenIn35mmFilm=\(focalLenIn35mmFilm), focalLength=\(focalLength), ISOSPEEDRatings=\(ISOSPEEDRatings), altitude=\(altitude), latitude=\(latitude), longitude=\(longitude), objectName=\(objectName), caption=\(caption)")
            }
        } else {
            print("INSERT statement for bulk photo could not be prepared.")
        }
        sqlite3_finalize(insertStatement)
        return false
    }
    
}
