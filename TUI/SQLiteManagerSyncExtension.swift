import Foundation
import SQLite3

// 同步操作类型
enum SyncOperationType: String {
    case add = "ADD"
    case update = "UPDATE"
    case delete = "DELETE"
}

// 同步记录
struct SyncRecord {
    let id: String
    let tableType: String
    let recordId: String
    let operationType: SyncOperationType
    let timestamp: Date
    let syncStatus: String // PENDING, SYNCED, FAILED
    let errorMessage: String?
}

// 同步状态结构体
struct PhotoSyncStatus {
    var lastSyncTime: Date?
    var isSyncing: Bool
    var pendingChanges: Int
    var syncError: String?
}

// SQLiteManager同步扩展
extension SQLiteManager {
    
    // 执行数据库操作的包装方法（解决私有队列访问问题）
    private func executeSyncOperation<T>(_ operation: (OpaquePointer?) -> T) -> T {
        var result: T!
        
        // 直接在数据库上执行操作，不使用私有队列
        if let db = self.db {
            result = operation(db)
        } else {
            fatalError("数据库连接未初始化")
        }
        
        return result
    }
    
    // 创建同步表
    public func createSyncTables() {
        let syncTableSQL = """
        CREATE TABLE IF NOT EXISTS SyncRecords (
            id TEXT PRIMARY KEY,
            tableType TEXT NOT NULL,
            recordId TEXT NOT NULL,
            operationType TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            syncStatus TEXT NOT NULL,
            errorMessage TEXT
        );
        """
        
        executeSyncOperation { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, syncTableSQL, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("同步记录表创建成功")
                } else {
                    print("同步记录表创建失败")
                }
            } else {
                print("准备同步记录表SQL语句失败")
            }
        }
    }
    
    // 添加同步记录
    public func addSyncRecord(tableType: String, recordId: String, operationType: SyncOperationType) -> Bool {
        let syncRecordId = UUID().uuidString
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let insertSQL = """
        INSERT INTO SyncRecords (id, tableType, recordId, operationType, timestamp, syncStatus, errorMessage)
        VALUES (?, ?, ?, ?, ?, 'PENDING', NULL);
        """
        
        return executeSyncOperation { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (syncRecordId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (tableType as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 3, (recordId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 4, (operationType.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 5, (timestamp as NSString).utf8String, -1, nil)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    return true
                } else {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    print("添加同步记录失败: \(errorMessage)")
                    return false
                }
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("准备添加同步记录SQL语句失败: \(errorMessage)")
                return false
            }
        }
    }
    
    // 获取待同步记录
    public func getPendingSyncRecords(limit: Int = 100) -> [SyncRecord] {
        let querySQL = """
        SELECT id, tableType, recordId, operationType, timestamp, syncStatus, errorMessage 
        FROM SyncRecords 
        WHERE syncStatus = 'PENDING' 
        ORDER BY timestamp ASC 
        LIMIT ?;
        """
        
        return executeSyncOperation { db in
            var records: [SyncRecord] = []
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(limit))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(statement, 0))
                    let tableType = String(cString: sqlite3_column_text(statement, 1))
                    let recordId = String(cString: sqlite3_column_text(statement, 2))
                    let operationTypeStr = String(cString: sqlite3_column_text(statement, 3))
                    let timestampStr = String(cString: sqlite3_column_text(statement, 4))
                    let syncStatus = String(cString: sqlite3_column_text(statement, 5))
                    
                    let operationType = SyncOperationType(rawValue: operationTypeStr) ?? .add
                    let dateFormatter = ISO8601DateFormatter()
                    let timestamp = dateFormatter.date(from: timestampStr) ?? Date()
                    
                    var errorMessage: String? = nil
                    if let errorText = sqlite3_column_text(statement, 6) {
                        errorMessage = String(cString: errorText)
                    }
                    
                    let record = SyncRecord(
                        id: id,
                        tableType: tableType,
                        recordId: recordId,
                        operationType: operationType,
                        timestamp: timestamp,
                        syncStatus: syncStatus,
                        errorMessage: errorMessage
                    )
                    
                    records.append(record)
                }
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("准备获取待同步记录SQL语句失败: \(errorMessage)")
            }
            
            return records
        }
    }
    
    // 更新同步记录状态
    public func updateSyncRecordStatus(id: String, syncStatus: String, errorMessage: String? = nil) -> Bool {
        let updateSQL = """
        UPDATE SyncRecords 
        SET syncStatus = ?, errorMessage = ? 
        WHERE id = ?;
        """
        
        return executeSyncOperation { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (syncStatus as NSString).utf8String, -1, nil)
                
                if let errorMessage = errorMessage {
                    sqlite3_bind_text(statement, 2, (errorMessage as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(statement, 2)
                }
                
                sqlite3_bind_text(statement, 3, (id as NSString).utf8String, -1, nil)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    return true
                } else {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    print("更新同步记录状态失败: \(errorMessage)")
                    return false
                }
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("准备更新同步记录状态SQL语句失败: \(errorMessage)")
                return false
            }
        }
    }
    
    // 获取同步状态
    public func getSyncStatus() -> PhotoSyncStatus {
        let pendingCountSQL = "SELECT COUNT(*) FROM SyncRecords WHERE syncStatus = 'PENDING';"
        let lastSyncSQL = "SELECT MAX(timestamp) FROM SyncRecords WHERE syncStatus = 'SYNCED';"
        
        return executeSyncOperation { db in
            var status = PhotoSyncStatus(lastSyncTime: nil, isSyncing: false, pendingChanges: 0, syncError: nil)
            
            // 获取待同步记录数
            var countStatement: OpaquePointer?
            defer { sqlite3_finalize(countStatement) }
            
            if sqlite3_prepare_v2(db, pendingCountSQL, -1, &countStatement, nil) == SQLITE_OK {
                if sqlite3_step(countStatement) == SQLITE_ROW {
                    status.pendingChanges = Int(sqlite3_column_int(countStatement, 0))
                }
            }
            
            // 获取最后同步时间
            var timeStatement: OpaquePointer?
            defer { sqlite3_finalize(timeStatement) }
            
            if sqlite3_prepare_v2(db, lastSyncSQL, -1, &timeStatement, nil) == SQLITE_OK {
                if sqlite3_step(timeStatement) == SQLITE_ROW {
                    if let timestampText = sqlite3_column_text(timeStatement, 0) {
                        let timestampStr = String(cString: timestampText)
                        let dateFormatter = ISO8601DateFormatter()
                        status.lastSyncTime = dateFormatter.date(from: timestampStr)
                    }
                }
            }
            
            // 获取最近的同步错误（如果有）
            let errorSQL = """
            SELECT errorMessage FROM SyncRecords 
            WHERE syncStatus = 'FAILED' 
            ORDER BY timestamp DESC 
            LIMIT 1;
            """
            
            var errorStatement: OpaquePointer?
            defer { sqlite3_finalize(errorStatement) }
            
            if sqlite3_prepare_v2(db, errorSQL, -1, &errorStatement, nil) == SQLITE_OK {
                if sqlite3_step(errorStatement) == SQLITE_ROW {
                    if let errorText = sqlite3_column_text(errorStatement, 0) {
                        status.syncError = String(cString: errorText)
                    }
                }
            }
            
            return status
        }
    }
    
    // 当添加照片时自动创建同步记录
    public func addPhotoWithSync(
        id: String, title: String, path: String, thumbnailPath100: String, thumbnailPath350: String,
        starRating: Int, country: String, area: String, locality: String,
        dateTimeOriginal: String, addTimestamp: String, lensModel: String, model: String,
        exposureTime: Double, fNumber: Double, focalLenIn35mmFilm: Double, focalLength: Double,
        ISOSPEEDRatings: Int, altitude: Double, latitude: Double, longitude: Double,
        objectName: String, caption: String
    ) -> Bool {
        // 首先添加照片记录
        let success = addPhoto(
            id: id, title: title, path: path, thumbnailPath100: thumbnailPath100, thumbnailPath350: thumbnailPath350,
            starRating: starRating, country: country, area: area, locality: locality,
            dateTimeOriginal: dateTimeOriginal, addTimestamp: addTimestamp, lensModel: lensModel, model: model,
            exposureTime: exposureTime, fNumber: fNumber, focalLenIn35mmFilm: focalLenIn35mmFilm, focalLength: focalLength,
            ISOSPEEDRatings: ISOSPEEDRatings, altitude: altitude, latitude: latitude, longitude: longitude,
            objectName: objectName, caption: caption
        )
        
        // 如果照片添加成功，则创建同步记录
        if success {
            _ = addSyncRecord(tableType: "Photos", recordId: id, operationType: .add)
        }
        
        return success
    }
    
    // 当更新照片时自动创建同步记录
    public func updatePhotoRecordWithSync(
        imagePath: String, objectName: String, caption: String, starRating: Int,
        latitude: Double, longitude: Double, country: String, area: String, locality: String
    ) -> Bool {
        // 首先获取照片ID
        guard let photo = getPhoto(for: imagePath) else {
            return false
        }
        
        // 使用现有的updatePhotoRecord方法更新照片
        updatePhotoRecord(
            imagePath: imagePath,
            objectName: objectName,
            caption: caption,
            starRating: starRating,
            latitude: latitude,
            longitude: longitude,
            country: country,
            area: area,
            locality: locality
        )
        
        // 创建同步记录
        _ = addSyncRecord(tableType: "Photos", recordId: photo.id, operationType: .update)
        
        return true
    }
    
    // 当删除照片时自动创建同步记录
    public func deletePhotoRecordWithSync(imagePath: String) -> Bool {
        // 首先获取照片ID
        guard let photo = getPhoto(for: imagePath) else {
            return false
        }
        
        // 创建同步记录
        let syncSuccess = addSyncRecord(tableType: "Photos", recordId: photo.id, operationType: .delete)
        
        if !syncSuccess {
            print("无法为删除操作创建同步记录")
        }
        
        // 使用现有的deletePhotoRecord方法删除照片
        deletePhotoRecord(imagePath: imagePath)
        
        return true
    }
    
    // 清理已同步的记录（保留最近的记录）
    public func cleanupSyncedRecords(keepDays: Int = 7) -> Int {
        let deleteSQL = """
        DELETE FROM SyncRecords 
        WHERE syncStatus = 'SYNCED' 
        AND timestamp < datetime('now', '-\(keepDays) days');
        """
        
        return executeSyncOperation { db in
            var count = 0
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            
            if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_DONE {
                    count = Int(sqlite3_changes(db))
                } else {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    print("清理已同步记录失败: \(errorMessage)")
                }
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("准备清理已同步记录SQL语句失败: \(errorMessage)")
            }
            
            return count
        }
    }
}
