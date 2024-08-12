import Foundation
import SQLite3

class SQLiteManager {
    static let shared = SQLiteManager()
    public var db: OpaquePointer?
    private var cachedPhotos: [Photo]?
    private var lastSortOrder: Bool?
    
    private init() {
        openDatabase()
        createTable()
    }
    
    private func openDatabase() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsDirectory.appendingPathComponent("photos.sqlite").path
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Unable to open database.")
        } else {
            //print("Database opened at \(dbPath)")
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
            } else {
                print("Photos table could not be created.")
            }
        } else {
            print("CREATE TABLE statement could not be prepared.")
        }
        sqlite3_finalize(createTableStatement)
    }
    
    func addPhoto(id: String, title: String, path: String, thumbnailPath100: String, thumbnailPath350: String, starRating: Int, country: String, area: String, locality: String, dateTimeOriginal: String, addTimestamp: String, lensModel: String, model: String, exposureTime: Double, fNumber: Double, focalLenIn35mmFilm: Double, focalLength: Double, ISOSPEEDRatings: Int, altitude: Double, latitude: Double, longitude: Double, objectName: String, caption: String) -> Bool {
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
//                print("Successfully inserted row.")
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
    
    func updateDatabase() {
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
    
    func getPhoto(for path: String) -> Photo? {
        let queryStatementString = "SELECT * FROM Photos WHERE Path = ? LIMIT 1;"
        var queryStatement: OpaquePointer?
        var photo: Photo?
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (path as NSString).utf8String, -1, nil)
            
            if sqlite3_step(queryStatement) == SQLITE_ROW {
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
                
                photo = Photo(id: id, title: title, path: path, thumbnailPath100: thumbnailPath100, thumbnailPath350: thumbnailPath350, starRating: Int(starRating), country: country, area: area, locality: locality, dateTimeOriginal: dateTimeOriginal, addTimestamp: addTimestamp, lensModel: lensModel, model: model, exposureTime: exposureTime, fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm, focalLength: focalLength, ISOSPEEDRatings: Int(ISOSPEEDRatings), altitude: altitude, latitude: latitude, longitude: longitude, objectName: objectName, caption: caption)
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        return photo
    }
    
    func getPhotos(for date: String) -> [Photo] {
        let queryStatementString = "SELECT * FROM Photos WHERE DateTimeOriginal LIKE ?;"
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            let datePattern = "\(date)%"
            sqlite3_bind_text(queryStatement, 1, (datePattern as NSString).utf8String, -1, nil)
            
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
    
    func getAllObjectNames() -> [String: Int] {
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
    
    func getMonthPhotos(forYear year: Int, month: Int) -> [Photo] {
        let queryStatementString = "SELECT * FROM Photos WHERE DateTimeOriginal LIKE ?;"
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            let dateTimePattern = "\(year)-\(String(format: "%02d", month))%"
            sqlite3_bind_text(queryStatement, 1, dateTimePattern, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(queryStatement, 0))
                let title = String(cString: sqlite3_column_text(queryStatement, 1))
                let path = String(cString: sqlite3_column_text(queryStatement, 2))
                let thumbnailPath100 = String(cString: sqlite3_column_text(queryStatement, 3))
                let thumbnailPath350 = String(cString: sqlite3_column_text(queryStatement, 4))
                let starRating = sqlite3_column_int(queryStatement, 5)
                let country = String(cString: sqlite3_column_text(queryStatement, 6))
                let area = String(cString: sqlite3_column_text(queryStatement, 7))
                let locality = String(cString: sqlite3_column_text(queryStatement, 8))
                let dateTimeOriginal = String(cString: sqlite3_column_text(queryStatement, 9))
                let addTimestamp = String(cString: sqlite3_column_text(queryStatement, 10))
                let lensModel = String(cString: sqlite3_column_text(queryStatement, 11))
                let model = String(cString: sqlite3_column_text(queryStatement, 12))
                let exposureTime = sqlite3_column_double(queryStatement, 13)
                let fNumber = sqlite3_column_double(queryStatement, 14)
                let focalLenIn35mmFilm = sqlite3_column_double(queryStatement, 15)
                let focalLength = sqlite3_column_double(queryStatement, 16)
                let ISOSPEEDRatings = sqlite3_column_int(queryStatement, 17)
                let altitude = sqlite3_column_double(queryStatement, 18)
                let latitude = sqlite3_column_double(queryStatement, 19)
                let longitude = sqlite3_column_double(queryStatement, 20)
                let objectName = String(cString: sqlite3_column_text(queryStatement, 21))
                let caption = String(cString: sqlite3_column_text(queryStatement, 22))
                
                photos.append(Photo(id: id, title: title, path: path, thumbnailPath100: thumbnailPath100, thumbnailPath350: thumbnailPath350, starRating: Int(starRating), country: country, area: area, locality: locality, dateTimeOriginal: dateTimeOriginal, addTimestamp: addTimestamp, lensModel: lensModel, model: model, exposureTime: exposureTime, fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm, focalLength: focalLength, ISOSPEEDRatings: Int(ISOSPEEDRatings), altitude: altitude, latitude: latitude, longitude: longitude, objectName: objectName, caption: caption))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        return photos
    }
    
    func getPhotoHistory() -> [Photo] {
        let queryStatementString = "SELECT * FROM Photos;"
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
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
    
    func getAllPhotos(sortByShootingTime: Bool = true) -> [Photo] {
        if let cachedPhotos = cachedPhotos, lastSortOrder == sortByShootingTime {
            return cachedPhotos
        }
        
        let queryStatementString = sortByShootingTime ?
        "SELECT * FROM Photos ORDER BY DateTimeOriginal DESC;" :
        "SELECT * FROM Photos ORDER BY AddTimestamp DESC;"
        
        var queryStatement: OpaquePointer?
        var photos: [Photo] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
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
                
                photos.append(Photo(id: id, title: title, path: path, thumbnailPath100: thumbnailPath100, thumbnailPath350: thumbnailPath350, starRating: Int(starRating), country: country, area: area, locality: locality, dateTimeOriginal: dateTimeOriginal, addTimestamp: addTimestamp, lensModel: lensModel, model: model, exposureTime: exposureTime, fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm, focalLength: focalLength, ISOSPEEDRatings: Int(ISOSPEEDRatings),altitude: altitude, latitude: latitude, longitude: longitude, objectName: objectName, caption: caption))
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        sqlite3_finalize(queryStatement)
        
        cachedPhotos = photos
        lastSortOrder = sortByShootingTime
        return photos
    }
    
    func invalidateCache() {
        cachedPhotos = nil
        lastSortOrder = nil
    }
    
    func getPhotoCountsByCountryAndCity() -> [String: [String: Int]] {
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
    
    func getPhotosByCountryOrLocality(_ name: String) -> [(count: Int, latitude: Double, longitude: Double)] {
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
    
    func getPhotosByDatePattern(_ dateTimePattern: String) -> [Photo] {
        var queryStatement: OpaquePointer?
        let queryStatementString = "SELECT * FROM Photos WHERE DateTimeOriginal LIKE '\(dateTimePattern)'"
        var photos: [Photo] = []
        
        print("Attempting to prepare SQL statement")
        print("Executing SQL query: \(queryStatementString)")
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            var stepResult = sqlite3_step(queryStatement)
            if stepResult != SQLITE_ROW {
                print("No rows found. sqlite3_step result: \(stepResult)")
            }
            
            while stepResult == SQLITE_ROW {
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
                
                stepResult = sqlite3_step(queryStatement)
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("SELECT statement could not be prepared. Error: \(errorMessage)")
        }
        sqlite3_finalize(queryStatement)
        print("Query completed. Found \(photos.count) photos.")
        return photos
    }
    
    func searchPhotos(keyword: String, limit: Int = 9, offset: Int = 0) -> [Photo] {
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
    
    func countPhotos(keyword: String) -> Int {
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
    
    func deletePhotoRecord(imagePath: String) {
        let deleteStatementString = "DELETE FROM Photos WHERE Path = ?;"
        var deleteStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStatement, 1, (imagePath as NSString).utf8String, -1, nil)
            
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                //print("Successfully deleted row.")
            } else {
                print("Could not delete row.")
            }
        } else {
            print("DELETE statement could not be prepared.")
        }
        sqlite3_finalize(deleteStatement)
    }
    
    func updatePhotoRecord(imagePath: String, objectName: String, caption: String, starRating: Int) {
         let updateStatementString = """
         UPDATE Photos
         SET ObjectName = ?, Caption = ?, StarRating = ?
         WHERE Path = ?;
         """
         var updateStatement: OpaquePointer?
         
         if sqlite3_prepare_v2(db, updateStatementString, -1, &updateStatement, nil) == SQLITE_OK {
             sqlite3_bind_text(updateStatement, 1, (objectName as NSString).utf8String, -1, nil)
             sqlite3_bind_text(updateStatement, 2, (caption as NSString).utf8String, -1, nil)
             sqlite3_bind_int(updateStatement, 3, Int32(starRating))
             sqlite3_bind_text(updateStatement, 4, (imagePath as NSString).utf8String, -1, nil)
             
             if sqlite3_step(updateStatement) == SQLITE_DONE {
                 //print("Successfully updated photo record.")
             } else {
                 print("Could not update photo record.")
             }
         } else {
             print("UPDATE statement could not be prepared.")
         }
         sqlite3_finalize(updateStatement)
     }
}
