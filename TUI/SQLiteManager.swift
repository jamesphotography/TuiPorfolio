import Foundation
import SQLite3

class SQLiteManager {
    static let shared = SQLiteManager()
    public var db: OpaquePointer?
    private var cachedPhotos: [Photo]?
    private var lastSortOrder: Bool?
    
    private let dbQueue = DispatchQueue(label: "jamesphotography.TUI.sqlite")
    
    private init() {
        dbQueue.sync {
            openDatabase()
            createTable()
        }
    }
    
    private func openDatabase() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsDirectory.appendingPathComponent("photos.sqlite").path
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Unable to open database.")
        }
    }
    
    private func createTable() {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS Photos(
        Id TEXT PRIMARY KEY,
        Title TEXT,
        Path TEXT,
        ThumbnailPath100 TEXT,
        ThumbnailPath350 TEXT,
        StarRating INTEGER,
        Country TEXT,
        Area TEXT,
        Locality TEXT,
        DateTimeOriginal TEXT,
        AddTimestamp TEXT,
        LensModel TEXT,
        Model TEXT,
        ExposureTime REAL,
        FNumber REAL,
        FocalLenIn35mmFilm REAL,
        FocalLength REAL,
        ISOSPEEDRatings INTEGER,
        Altitude REAL,
        Latitude REAL,
        Longitude REAL,
        ObjectName TEXT,
        Caption TEXT);
        """
        
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("Photos table created.")
            } else {
                print("Photos table could not be created.")
            }
        } else {
            print("CREATE TABLE statement could not be prepared.")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    // 1. addPhoto
    func addPhoto(id: String, title: String, path: String, thumbnailPath100: String, thumbnailPath350: String, starRating: Int, country: String, area: String, locality: String, dateTimeOriginal: String, addTimestamp: String, lensModel: String, model: String, exposureTime: Double, fNumber: Double, focalLenIn35mmFilm: Double, focalLength: Double, ISOSPEEDRatings: Int, altitude: Double, latitude: Double, longitude: Double, objectName: String, caption: String) -> Bool {
        var result = false
        dbQueue.sync {
            result = self._addPhoto(id: id, title: title, path: path, thumbnailPath100: thumbnailPath100, thumbnailPath350: thumbnailPath350, starRating: starRating, country: country, area: area, locality: locality, dateTimeOriginal: dateTimeOriginal, addTimestamp: addTimestamp, lensModel: lensModel, model: model, exposureTime: exposureTime, fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm, focalLength: focalLength, ISOSPEEDRatings: ISOSPEEDRatings, altitude: altitude, latitude: latitude, longitude: longitude, objectName: objectName, caption: caption)
        }
        return result
    }
    
    private func _addPhoto(id: String, title: String, path: String, thumbnailPath100: String, thumbnailPath350: String, starRating: Int, country: String, area: String, locality: String, dateTimeOriginal: String, addTimestamp: String, lensModel: String, model: String, exposureTime: Double, fNumber: Double, focalLenIn35mmFilm: Double, focalLength: Double, ISOSPEEDRatings: Int, altitude: Double, latitude: Double, longitude: Double, objectName: String, caption: String) -> Bool {
        let insertStatementString = """
        INSERT INTO Photos (Id, Title, Path, ThumbnailPath100, ThumbnailPath350, StarRating, Country, Area, Locality, DateTimeOriginal, AddTimestamp, LensModel, Model, ExposureTime, FNumber, FocalLenIn35mmFilm, FocalLength, ISOSPEEDRatings, Altitude, Latitude, Longitude, ObjectName, Caption) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
            sqlite3_bind_text(insertStatement, 11, (addTimestamp as NSString).utf8String, -1, nil)
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
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                sqlite3_finalize(insertStatement)
                return true
            } else {
                print("Could not insert row.")
            }
        } else {
            print("INSERT statement could not be prepared.")
        }
        sqlite3_finalize(insertStatement)
        return false
    }
    
    // 2. getPhoto
    func getPhoto(for path: String) -> Photo? {
        var photo: Photo?
        dbQueue.sync {
            photo = self._getPhoto(for: path)
        }
        return photo
    }
    
    private func _getPhoto(for path: String) -> Photo? {
        let queryStatementString = "SELECT * FROM Photos WHERE Path = ? LIMIT 1;"
        var queryStatement: OpaquePointer?
        var photo: Photo?
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (path as NSString).utf8String, -1, nil)
            
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                photo = createPhotoFromQueryResult(queryStatement)
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        return photo
    }
    
    // Helper method to create Photo object from query result
    private func createPhotoFromQueryResult(_ queryStatement: OpaquePointer?) -> Photo? {
        guard let queryStatement = queryStatement else { return nil }
        
        guard let id = sqlite3_column_text(queryStatement, 0),
              let title = sqlite3_column_text(queryStatement, 1),
              let path = sqlite3_column_text(queryStatement, 2),
              let thumbnailPath100 = sqlite3_column_text(queryStatement, 3),
              let thumbnailPath350 = sqlite3_column_text(queryStatement, 4),
              let country = sqlite3_column_text(queryStatement, 6),
              let area = sqlite3_column_text(queryStatement, 7),
              let locality = sqlite3_column_text(queryStatement, 8),
              let dateTimeOriginal = sqlite3_column_text(queryStatement, 9),
              let addTimestamp = sqlite3_column_text(queryStatement, 10),
              let lensModel = sqlite3_column_text(queryStatement, 11),
              let model = sqlite3_column_text(queryStatement, 12),
              let objectName = sqlite3_column_text(queryStatement, 21),
              let caption = sqlite3_column_text(queryStatement, 22)
        else {
            return nil
        }
        
        let idString = String(cString: id)
        let titleString = String(cString: title)
        let pathString = String(cString: path)
        let thumbnailPath100String = String(cString: thumbnailPath100)
        let thumbnailPath350String = String(cString: thumbnailPath350)
        let countryString = String(cString: country)
        let areaString = String(cString: area)
        let localityString = String(cString: locality)
        let dateTimeOriginalString = String(cString: dateTimeOriginal)
        let addTimestampString = String(cString: addTimestamp)
        let lensModelString = String(cString: lensModel)
        let modelString = String(cString: model)
        let objectNameString = String(cString: objectName)
        let captionString = String(cString: caption)
        
        let starRating = sqlite3_column_int(queryStatement, 5)
        let exposureTime = sqlite3_column_double(queryStatement, 13)
        let fNumber = sqlite3_column_double(queryStatement, 14)
        let focalLenIn35mmFilm = sqlite3_column_double(queryStatement, 15)
        let focalLength = sqlite3_column_double(queryStatement, 16)
        let ISOSPEEDRatings = sqlite3_column_int(queryStatement, 17)
        let altitude = sqlite3_column_double(queryStatement, 18)
        let latitude = sqlite3_column_double(queryStatement, 19)
        let longitude = sqlite3_column_double(queryStatement, 20)
        
        return Photo(id: idString, title: titleString, path: pathString, thumbnailPath100: thumbnailPath100String, thumbnailPath350: thumbnailPath350String, starRating: Int(starRating), country: countryString, area: areaString, locality: localityString, dateTimeOriginal: dateTimeOriginalString, addTimestamp: addTimestampString, lensModel: lensModelString, model: modelString, exposureTime: exposureTime, fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm, focalLength: focalLength, ISOSPEEDRatings: Int(ISOSPEEDRatings), altitude: altitude, latitude: latitude, longitude: longitude, objectName: objectNameString, caption: captionString)
    }
    
    // ... 更多方法将在下一部分继续
    // 继续 SQLiteManager 类
    
    // 3. getPhotos
    func getPhotos(for date: String) -> [Photo] {
        var photos: [Photo] = []
        dbQueue.sync {
            photos = self._getPhotos(for: date)
        }
        return photos
    }
    
    private func _getPhotos(for date: String) -> [Photo] {
        let queryStatementString = "SELECT * FROM Photos WHERE DateTimeOriginal LIKE ?;"
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            let datePattern = "\(date)%"
            sqlite3_bind_text(queryStatement, 1, (datePattern as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                if let photo = createPhotoFromQueryResult(queryStatement) {
                    photos.append(photo)
                }
            }
        } else {
            print("SELECT statement could not be prepared.")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }
    
    // 4. getAllPhotos
    func getAllPhotos(sortByShootingTime: Bool = true) -> [Photo] {
        var photos: [Photo] = []
        dbQueue.sync {
            photos = self._getAllPhotos(sortByShootingTime: sortByShootingTime)
        }
        return photos
    }
    
    private func _getAllPhotos(sortByShootingTime: Bool = true) -> [Photo] {
        if let cachedPhotos = cachedPhotos, lastSortOrder == sortByShootingTime {
            return cachedPhotos
        }
        
        let queryStatementString = sortByShootingTime ?
        "SELECT * FROM Photos ORDER BY DateTimeOriginal DESC;" :
        "SELECT * FROM Photos ORDER BY AddTimestamp DESC, DateTimeOriginal DESC;"
        
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                if let photo = createPhotoFromQueryResult(queryStatement) {
                    photos.append(photo)
                }
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        
        cachedPhotos = photos
        lastSortOrder = sortByShootingTime
        return photos
    }
    
    // 5. updateDatabase
    func updateDatabase() {
        dbQueue.sync {
            self._updateDatabase()
        }
    }
    
    private func _updateDatabase() {
        let addThumbnailPath100Column = "ALTER TABLE Photos ADD COLUMN ThumbnailPath100 TEXT;"
        let addThumbnailPath350Column = "ALTER TABLE Photos ADD COLUMN ThumbnailPath350 TEXT;"
        
        var alterTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, addThumbnailPath100Column, -1, &alterTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(alterTableStatement) == SQLITE_DONE {
                print("ThumbnailPath100 column added.")
            } else {
                print("Could not add ThumbnailPath100 column.")
            }
        } else {
            print("ALTER TABLE statement could not be prepared.")
        }
        sqlite3_finalize(alterTableStatement)
        
        if sqlite3_prepare_v2(db, addThumbnailPath350Column, -1, &alterTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(alterTableStatement) == SQLITE_DONE {
                print("ThumbnailPath350 column added.")
            } else {
                print("Could not add ThumbnailPath350 column.")
            }
        } else {
            print("ALTER TABLE statement could not be prepared.")
        }
        sqlite3_finalize(alterTableStatement)
    }
    
    // 6. getPhotoCountsByCountryAndCity
    func getPhotoCountsByCountryAndCity() -> [String: [String: Int]] {
        var results: [String: [String: Int]] = [:]
        dbQueue.sync {
            results = self._getPhotoCountsByCountryAndCity()
        }
        return results
    }
    
    private func _getPhotoCountsByCountryAndCity() -> [String: [String: Int]] {
        var results = [String: [String: Int]]()
        let query = """
                SELECT Country, Locality, COUNT(*) AS Count
                FROM Photos
                WHERE Country IS NOT NULL AND Country != '' AND Country != 'Unknown Country'
                AND Locality IS NOT NULL AND Locality != '' AND Locality != 'Unknown City'
                GROUP BY Country, Locality;
                """
        
        var queryStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let country = String(cString: sqlite3_column_text(queryStatement, 0))
                let locality = String(cString: sqlite3_column_text(queryStatement, 1))
                let count = Int(sqlite3_column_int(queryStatement, 2))
                
                if results[country] == nil {
                    results[country] = [String: Int]()
                }
                results[country]?[locality] = count
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("SELECT statement could not be prepared. Error: \(errorMessage)")
        }
        sqlite3_finalize(queryStatement)
        return results
    }
    
    // 7. getPhotosByCountryOrLocality
    func getPhotosByCountryOrLocality(_ name: String) -> [(count: Int, latitude: Double, longitude: Double)] {
        var results: [(count: Int, latitude: Double, longitude: Double)] = []
        dbQueue.sync {
            results = self._getPhotosByCountryOrLocality(name)
        }
        return results
    }
    
    private func _getPhotosByCountryOrLocality(_ name: String) -> [(count: Int, latitude: Double, longitude: Double)] {
        var results: [(count: Int, latitude: Double, longitude: Double)] = []
        let query = """
                SELECT Latitude, Longitude, COUNT(*)
                FROM Photos
                WHERE Country = ? OR Locality = ?
                GROUP BY Latitude, Longitude;
                """
        
        var queryStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 2, (name as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let latitude = sqlite3_column_double(queryStatement, 0)
                let longitude = sqlite3_column_double(queryStatement, 1)
                let count = Int(sqlite3_column_int(queryStatement, 2))
                results.append((count: count, latitude: latitude, longitude: longitude))
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("SELECT statement could not be prepared. Error: \(errorMessage)")
        }
        sqlite3_finalize(queryStatement)
        return results
    }
    
    // 继续 SQLiteManager 类
    
    // 8. getPhotosByDatePattern
    func getPhotosByDatePattern(_ dateTimePattern: String) -> [Photo] {
        var photos: [Photo] = []
        dbQueue.sync {
            photos = self._getPhotosByDatePattern(dateTimePattern)
        }
        return photos
    }
    
    private func _getPhotosByDatePattern(_ dateTimePattern: String) -> [Photo] {
        let queryStatementString = "SELECT * FROM Photos WHERE DateTimeOriginal LIKE '\(dateTimePattern)'"
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                if let photo = createPhotoFromQueryResult(queryStatement) {
                    photos.append(photo)
                }
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("SELECT statement could not be prepared. Error: \(errorMessage)")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }
    
    // 9. searchPhotos
    func searchPhotos(keyword: String, limit: Int = 9, offset: Int = 0) -> [Photo] {
        var photos: [Photo] = []
        dbQueue.sync {
            photos = self._searchPhotos(keyword: keyword, limit: limit, offset: offset)
        }
        return photos
    }
    
    private func _searchPhotos(keyword: String, limit: Int = 9, offset: Int = 0) -> [Photo] {
        let queryStatementString = """
                SELECT * FROM Photos
                WHERE Title LIKE ? OR ObjectName LIKE ? OR Caption LIKE ? OR Country LIKE ? OR Area LIKE ? OR Locality LIKE ?
                ORDER BY DateTimeOriginal DESC
                LIMIT ? OFFSET ?;
                """
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            let keywordPattern = "%\(keyword)%"
            sqlite3_bind_text(queryStatement, 1, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 2, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 3, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 4, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 5, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 6, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_int(queryStatement, 7, Int32(limit))
            sqlite3_bind_int(queryStatement, 8, Int32(offset))
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                if let photo = createPhotoFromQueryResult(queryStatement) {
                    photos.append(photo)
                }
            }
        } else {
            print("SELECT statement could not be prepared.")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }
    
    // 10. countPhotos
    func countPhotos(keyword: String) -> Int {
        var count = 0
        dbQueue.sync {
            count = self._countPhotos(keyword: keyword)
        }
        return count
    }
    
    private func _countPhotos(keyword: String) -> Int {
        let queryStatementString = """
                SELECT COUNT(*) FROM Photos
                WHERE Title LIKE ? OR ObjectName LIKE ? OR Caption LIKE ? OR Country LIKE ? OR Area LIKE ? OR Locality LIKE ?;
                """
        var queryStatement: OpaquePointer?
        var count: Int = 0
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            let keywordPattern = "%\(keyword)%"
            sqlite3_bind_text(queryStatement, 1, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 2, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 3, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 4, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 5, (keywordPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 6, (keywordPattern as NSString).utf8String, -1, nil)
            
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(queryStatement, 0))
            }
        } else {
            print("COUNT statement could not be prepared.")
        }
        sqlite3_finalize(queryStatement)
        return count
    }
    
    // 11. deletePhotoRecord
    func deletePhotoRecord(imagePath: String) {
        dbQueue.sync {
            self._deletePhotoRecord(imagePath: imagePath)
        }
    }
    
    private func _deletePhotoRecord(imagePath: String) {
        let deleteStatementString = "DELETE FROM Photos WHERE Path = ?;"
        var deleteStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStatement, 1, (imagePath as NSString).utf8String, -1, nil)
            
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                print("Successfully deleted row.")
            } else {
                print("Could not delete row.")
            }
        } else {
            print("DELETE statement could not be prepared.")
        }
        sqlite3_finalize(deleteStatement)
    }
    
    // 12. updatePhotoRecord
    func updatePhotoRecord(imagePath: String, objectName: String, caption: String, starRating: Int, latitude: Double, longitude: Double, country: String, area: String, locality: String) {
        dbQueue.sync {
            self._updatePhotoRecord(imagePath: imagePath, objectName: objectName, caption: caption, starRating: starRating, latitude: latitude, longitude: longitude, country: country, area: area, locality: locality)
        }
    }
    
    private func _updatePhotoRecord(imagePath: String, objectName: String, caption: String, starRating: Int, latitude: Double, longitude: Double, country: String, area: String, locality: String) {
        let updateStatementString = """
            UPDATE Photos
            SET ObjectName = ?, Caption = ?, StarRating = ?, Latitude = ?, Longitude = ?, Country = ?, Area = ?, Locality = ?
            WHERE Path = ?;
            """
        var updateStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateStatementString, -1, &updateStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(updateStatement, 1, (objectName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(updateStatement, 2, (caption as NSString).utf8String, -1, nil)
            sqlite3_bind_int(updateStatement, 3, Int32(starRating))
            sqlite3_bind_double(updateStatement, 4, latitude)
            sqlite3_bind_double(updateStatement, 5, longitude)
            sqlite3_bind_text(updateStatement, 6, (country as NSString).utf8String, -1, nil)
            sqlite3_bind_text(updateStatement, 7, (area as NSString).utf8String, -1, nil)
            sqlite3_bind_text(updateStatement, 8, (locality as NSString).utf8String, -1, nil)
            sqlite3_bind_text(updateStatement, 9, (imagePath as NSString).utf8String, -1, nil)
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("Successfully updated photo record.")
            } else {
                print("Could not update photo record.")
            }
        } else {
            print("UPDATE statement could not be prepared.")
        }
        sqlite3_finalize(updateStatement)
    }
    
    // 继续 SQLiteManager 类
    
    // 13. isPhotoExists
    func isPhotoExists(captureDate: String, fileNamePrefix: String) -> Bool {
        var exists = false
        dbQueue.sync {
            exists = self._isPhotoExists(captureDate: captureDate, fileNamePrefix: fileNamePrefix)
        }
        return exists
    }
    
    private func _isPhotoExists(captureDate: String, fileNamePrefix: String) -> Bool {
        let queryStatementString = "SELECT COUNT(*) FROM Photos WHERE dateTimeOriginal = ? AND title LIKE ?;"
        var queryStatement: OpaquePointer?
        var exists = false
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (captureDate as NSString).utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 2, (fileNamePrefix + "%" as NSString).utf8String, -1, nil)
            
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                let count = sqlite3_column_int(queryStatement, 0)
                exists = (count > 0)
            } else {
                print("Failed to execute query to check photo existence.")
            }
        } else {
            print("SELECT statement could not be prepared.")
        }
        
        sqlite3_finalize(queryStatement)
        return exists
    }
    
    // 14. getEarliestPhotoTimeForBirds
    func getEarliestPhotoTimeForBirds() -> [(String, String)] {
        var results: [(String, String)] = []
        dbQueue.sync {
            results = self._getEarliestPhotoTimeForBirds()
        }
        return results
    }
    
    private func _getEarliestPhotoTimeForBirds() -> [(String, String)] {
        let queryStatementString = """
            SELECT ObjectName, MIN(DateTimeOriginal) as EarliestPhoto
            FROM Photos
            WHERE ObjectName IS NOT NULL AND ObjectName != ''
            GROUP BY ObjectName
            ORDER BY EarliestPhoto ASC;
            """
        
        var queryStatement: OpaquePointer?
        var results: [(String, String)] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let objectName = String(cString: sqlite3_column_text(queryStatement, 0))
                let earliestPhoto = String(cString: sqlite3_column_text(queryStatement, 1))
                results.append((objectName, earliestPhoto))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        return results
    }
    
    // 15. getCameraInfo
    func getCameraInfo() -> [(String, Int, String)] {
        var results: [(String, Int, String)] = []
        dbQueue.sync {
            results = self._getCameraInfo()
        }
        return results
    }
    
    private func _getCameraInfo() -> [(String, Int, String)] {
        let queryStatementString = """
            SELECT Model, COUNT(*) as Count, MAX(DateTimeOriginal) as LatestPhoto
            FROM Photos
            WHERE Model IS NOT NULL AND Model != ''
            GROUP BY Model
            ORDER BY LatestPhoto DESC;
            """
        
        var queryStatement: OpaquePointer?
        var results: [(String, Int, String)] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let model = String(cString: sqlite3_column_text(queryStatement, 0))
                let count = Int(sqlite3_column_int(queryStatement, 1))
                let earliestPhoto = String(cString: sqlite3_column_text(queryStatement, 2))
                results.append((model, count, earliestPhoto))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        return results
    }
    
    // 16. getPhotosByObjectName
    func getPhotosByObjectName(_ objectName: String) -> [Photo] {
        var photos: [Photo] = []
        dbQueue.sync {
            photos = self._getPhotosByObjectName(objectName)
        }
        return photos
    }
    
    private func _getPhotosByObjectName(_ objectName: String) -> [Photo] {
        let queryStatementString = "SELECT * FROM Photos WHERE ObjectName LIKE ?;"
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (objectName as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                if let photo = createPhotoFromQueryResult(queryStatement) {
                    photos.append(photo)
                }
            }
        } else {
            print("SELECT statement could not be prepared.")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }
    
    // 事务管理方法
    @discardableResult
    func beginTransaction() -> Int32 {
        dbQueue.sync {
            sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        }
    }
    
    @discardableResult
    func commitTransaction() -> Int32 {
        dbQueue.sync {
            sqlite3_exec(db, "COMMIT", nil, nil, nil)
        }
    }
    
    @discardableResult
    func rollbackTransaction() -> Int32 {
        dbQueue.sync {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
        }
    }
    
    // 缓存管理
    func invalidateCache() {
        dbQueue.sync {
            cachedPhotos = nil
            lastSortOrder = nil
        }
    }
}

extension SQLiteManager {
    func getAllObjectNames() -> [String: Int] {
        var results: [String: Int] = [:]
        dbQueue.sync {
            results = self._getAllObjectNames()
        }
        return results
    }

    private func _getAllObjectNames() -> [String: Int] {
        let queryStatementString = """
             SELECT ObjectName, COUNT(*) as Count
             FROM Photos
             WHERE ObjectName IS NOT NULL AND ObjectName != ''
             GROUP BY ObjectName
             ORDER BY Count DESC;
             """
        
        var queryStatement: OpaquePointer?
        var results: [String: Int] = [:]
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let objectName = String(cString: sqlite3_column_text(queryStatement, 0))
                let count = Int(sqlite3_column_int(queryStatement, 1))
                results[objectName] = count
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        return results
    }
}

extension SQLiteManager {
    func getEarliestUploadTimeForBirds() -> [(String, String)] {
        var results: [(String, String)] = []
        dbQueue.sync {
            results = self._getEarliestUploadTimeForBirds()
        }
        return results
    }

    private func _getEarliestUploadTimeForBirds() -> [(String, String)] {
        let queryStatementString = """
        SELECT ObjectName, MIN(AddTimestamp) as EarliestUpload
        FROM Photos
        WHERE ObjectName IS NOT NULL AND ObjectName != ''
        GROUP BY ObjectName
        ORDER BY EarliestUpload ASC;
        """
        
        var queryStatement: OpaquePointer?
        var results: [(String, String)] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let objectName = String(cString: sqlite3_column_text(queryStatement, 0))
                let earliestUpload = String(cString: sqlite3_column_text(queryStatement, 1))
                results.append((objectName, earliestUpload))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        return results
    }
}

extension SQLiteManager {
    func getPhotoHistory() -> [Photo] {
        var photos: [Photo] = []
        dbQueue.sync {
            photos = self._getPhotoHistory()
        }
        return photos
    }

    private func _getPhotoHistory() -> [Photo] {
        let queryStatementString = "SELECT * FROM Photos ORDER BY AddTimestamp DESC;"
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                if let photo = createPhotoFromQueryResult(queryStatement) {
                    photos.append(photo)
                }
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }
}


extension SQLiteManager {
    func getBirdPhotosForArea(area: String) -> [Photo] {
        var photos: [Photo] = []
        dbQueue.sync {
            photos = self._getBirdPhotosForArea(area: area)
        }
        return photos
    }

    private func _getBirdPhotosForArea(area: String) -> [Photo] {
        let queryStatementString = """
            SELECT * FROM Photos
            WHERE Area = ? AND ObjectName IS NOT NULL AND ObjectName != ''
            ORDER BY DateTimeOriginal DESC
        """
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (area as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                if let photo = createPhotoFromQueryResult(queryStatement) {
                    photos.append(photo)
                }
            }
        } else {
            print("SELECT statement could not be prepared.")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }
}

extension SQLiteManager {
    func getPhotosForArea(area: String) -> [Photo] {
        var photos: [Photo] = []
        dbQueue.sync {
            let queryStatementString = """
                SELECT * FROM Photos
                WHERE Area = ?
                ORDER BY DateTimeOriginal DESC;
                """
            
            var queryStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(queryStatement, 1, (area as NSString).utf8String, -1, nil)
                
                while sqlite3_step(queryStatement) == SQLITE_ROW {
                    if let photo = createPhotoFromQueryResult(queryStatement) {
                        photos.append(photo)
                    }
                }
            }
            sqlite3_finalize(queryStatement)
        }
        return photos
    }
}
