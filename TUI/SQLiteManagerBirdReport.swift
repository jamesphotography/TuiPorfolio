import Foundation
import SQLite3

extension SQLiteManager {
    // 静态属性缓存
    private static var birdListCache: [[String]]?
    private static var birdSpeciesSetCache: Set<String>?
    
    private var birdList: [[String]] {
        if let cached = SQLiteManager.birdListCache {
            return cached
        }
        let loaded = loadBirdListFromFile()
        SQLiteManager.birdListCache = loaded
        return loaded
    }
    
    private var birdSpeciesSet: Set<String> {
        if let cached = SQLiteManager.birdSpeciesSetCache {
            return cached
        }
        var speciesSet = Set<String>()
        birdList.forEach { names in
            names.forEach { speciesSet.insert($0) }
        }
        SQLiteManager.birdSpeciesSetCache = speciesSet
        return speciesSet
    }
    
    private func loadBirdListFromFile() -> [[String]] {
        guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let birdList = try? JSONDecoder().decode([[String]].self, from: data) else {
            print("Error loading bird list")
            return []
        }
        return birdList
    }
    
    private func isBirdSpecies(_ name: String) -> Bool {
        return birdSpeciesSet.contains(name)
    }
    
    func getBirdPhotosStats(for year: Int) -> (totalPhotos: Int, speciesCount: Int)? {
        let speciesSet = self.birdSpeciesSet
        var result: (totalPhotos: Int, speciesCount: Int)?
        
        let queryStatementString = """
            WITH BirdPhotos AS (
                SELECT ObjectName, COUNT(*) as PhotoCount
                FROM Photos 
                WHERE strftime('%Y', DateTimeOriginal) = ?
                AND ObjectName IN (SELECT DISTINCT value FROM json_each(?))
                GROUP BY ObjectName
            )
            SELECT 
                COALESCE(SUM(PhotoCount), 0) as TotalPhotos,
                COUNT(*) as SpeciesCount
            FROM BirdPhotos;
            """
        
        executeStatement(queryStatementString) { statement in
            let speciesJSON = try? JSONSerialization.data(withJSONObject: Array(speciesSet))
            let speciesJSONString = String(data: speciesJSON ?? Data(), encoding: .utf8) ?? "[]"
            
            sqlite3_bind_text(statement, 1, (String(year) as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (speciesJSONString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                result = (
                    Int(sqlite3_column_int(statement, 0)),
                    Int(sqlite3_column_int(statement, 1))
                )
            }
        }
        
        return result
    }
    
    func getYearlyBirdSpecies(for year: Int) -> [(String, Date, Bool)] {
        let speciesSet = self.birdSpeciesSet
        var results: [(String, Date, Bool)] = []
        
        let queryStatementString = """
            WITH YearFirstSeen AS (
                SELECT 
                    ObjectName,
                    MIN(DateTimeOriginal) as FirstSeen
                FROM Photos
                WHERE strftime('%Y', DateTimeOriginal) = ?
                AND ObjectName IN (SELECT DISTINCT value FROM json_each(?))
                GROUP BY ObjectName
            ),
            AllTimeFirstSeen AS (
                SELECT 
                    ObjectName,
                    MIN(DateTimeOriginal) as FirstEverSeen
                FROM Photos
                GROUP BY ObjectName
            )
            SELECT 
                y.ObjectName,
                y.FirstSeen,
                CASE 
                    WHEN y.FirstSeen = a.FirstEverSeen THEN 1 
                    ELSE 0 
                END as IsNew
            FROM YearFirstSeen y
            JOIN AllTimeFirstSeen a ON y.ObjectName = a.ObjectName
            ORDER BY y.FirstSeen;
            """
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        executeStatement(queryStatementString) { statement in
            let speciesJSON = try? JSONSerialization.data(withJSONObject: Array(speciesSet))
            let speciesJSONString = String(data: speciesJSON ?? Data(), encoding: .utf8) ?? "[]"
            
            sqlite3_bind_text(statement, 1, (String(year) as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (speciesJSONString as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let speciesName = sqlite3_column_text(statement, 0),
                   let firstSeenText = sqlite3_column_text(statement, 1) {
                    let name = String(cString: speciesName)
                    let dateStr = String(cString: firstSeenText)
                    if let date = dateFormatter.date(from: dateStr) {
                        let isNew = sqlite3_column_int(statement, 2) == 1
                        results.append((name, date, isNew))
                    }
                }
            }
        }
        
        return results
    }
    
    func getBirdSpeciesRanking() -> [String: Int] {
        let speciesSet = self.birdSpeciesSet
        var rankings: [String: Int] = [:]
        
        let queryStatementString = """
            WITH RankedSpecies AS (
                SELECT 
                    ObjectName,
                    ROW_NUMBER() OVER (ORDER BY MIN(DateTimeOriginal)) as Ranking
                FROM Photos
                WHERE ObjectName IN (SELECT DISTINCT value FROM json_each(?))
                GROUP BY ObjectName
            )
            SELECT ObjectName, Ranking 
            FROM RankedSpecies;
            """
        
        executeStatement(queryStatementString) { statement in
            let speciesJSON = try? JSONSerialization.data(withJSONObject: Array(speciesSet))
            let speciesJSONString = String(data: speciesJSON ?? Data(), encoding: .utf8) ?? "[]"
            
            sqlite3_bind_text(statement, 1, (speciesJSONString as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let speciesName = sqlite3_column_text(statement, 0) {
                    let name = String(cString: speciesName)
                    let rank = Int(sqlite3_column_int(statement, 1))
                    rankings[name] = rank
                }
            }
        }
        
        return rankings
    }
    
    func getAvailableBirdPhotoYears() -> [Int] {
        let speciesSet = self.birdSpeciesSet
        var years: [Int] = []
        
        let queryStatementString = """
            SELECT DISTINCT strftime('%Y', DateTimeOriginal) as Year
            FROM Photos
            WHERE ObjectName IN (SELECT DISTINCT value FROM json_each(?))
            GROUP BY Year
            HAVING COUNT(*) > 0
            ORDER BY Year DESC;
            """
        
        executeStatement(queryStatementString) { statement in
            let speciesJSON = try? JSONSerialization.data(withJSONObject: Array(speciesSet))
            let speciesJSONString = String(data: speciesJSON ?? Data(), encoding: .utf8) ?? "[]"
            
            sqlite3_bind_text(statement, 1, (speciesJSONString as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let yearText = sqlite3_column_text(statement, 0) {
                    let yearStr = String(cString: yearText)
                    if let year = Int(yearStr) {
                        years.append(year)
                    }
                }
            }
        }
        
        return years
    }
    
    // 辅助方法：执行数据库语句
    private func executeStatement(_ sql: String, operation: (OpaquePointer) -> Void) {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        beginTransaction()
        defer { commitTransaction() }
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let stmt = statement else {
            return
        }
        
        operation(stmt)
    }
}
