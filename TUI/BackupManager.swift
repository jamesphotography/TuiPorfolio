import Foundation
import ZipArchive

class BackupManager {
    static let shared = BackupManager()
    private let fileManager = FileManager.default
    
    private init() {}
    
    enum BackupError: Error {
        case failedToCreateDirectory
        case failedToCopyFile
        case failedToCreateZip
        case failedToUnzip
        case invalidBackup
        case emptyUsername
    }
    
    func createBackup(username: String, progressUpdate: @escaping (Double) -> Void) async throws -> URL {
        guard !username.isEmpty else {
            throw BackupError.emptyUsername
        }
        
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backupFileName = "TuiBackup_\(Date().ISO8601Format())_\(username).zip"
        let backupURL = documentsURL.appendingPathComponent(backupFileName)
        let tempBackupDirURL = documentsURL.appendingPathComponent("TempBackup")
        
        defer {
            try? fileManager.removeItem(at: tempBackupDirURL)
        }
        
        do {
            try fileManager.createDirectory(at: tempBackupDirURL, withIntermediateDirectories: true, attributes: nil)
            progressUpdate(0.1)
            
            try await backupDatabase(to: tempBackupDirURL)
            progressUpdate(0.4)
            
            try await backupImages(to: tempBackupDirURL)
            progressUpdate(0.7)
            
            guard SSZipArchive.createZipFile(atPath: backupURL.path, withContentsOfDirectory: tempBackupDirURL.path) else {
                throw BackupError.failedToCreateZip
            }
            progressUpdate(1.0)

            return backupURL
        } catch {
            print("Backup failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func restoreBackup(from backupURL: URL, progressUpdate: @escaping (Double) -> Void) async throws {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tempRestoreDirURL = documentsURL.appendingPathComponent("TempRestore")
        
        defer {
            try? fileManager.removeItem(at: tempRestoreDirURL)
        }
        
        do {
            try fileManager.createDirectory(at: tempRestoreDirURL, withIntermediateDirectories: true, attributes: nil)
            progressUpdate(0.1)
            
            guard SSZipArchive.unzipFile(atPath: backupURL.path, toDestination: tempRestoreDirURL.path) else {
                throw BackupError.failedToUnzip
            }
            progressUpdate(0.4)
            
            try await restoreDatabase(from: tempRestoreDirURL)
            progressUpdate(0.7)
            
            try await restoreImages(from: tempRestoreDirURL)
            progressUpdate(1.0)
            
            print("Backup successfully restored")
        } catch {
            print("Restore failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func getBackupsDirectory() throws -> URL {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw BackupError.failedToCreateDirectory
        }
        
        let backupsURL = appSupportURL.appendingPathComponent("Backups", isDirectory: true)
        
        if !fileManager.fileExists(atPath: backupsURL.path) {
            try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return backupsURL
    }
    
    private func backupDatabase(to directory: URL) async throws {
        let dbURL = getDocumentsDirectory().appendingPathComponent("photos.sqlite")
        let backupDBURL = directory.appendingPathComponent("photos.sqlite")
        try fileManager.copyItem(at: dbURL, to: backupDBURL)
    }
    
    private func backupImages(to directory: URL) async throws {
        let imagesURL = getDocumentsDirectory().appendingPathComponent("portfolio")
        let backupImagesURL = directory.appendingPathComponent("portfolio")
        try fileManager.copyItem(at: imagesURL, to: backupImagesURL)
    }
    
    private func restoreDatabase(from directory: URL) async throws {
        let currentDBURL = getDocumentsDirectory().appendingPathComponent("photos.sqlite")
        let backupDBURL = directory.appendingPathComponent("photos.sqlite")
        if fileManager.fileExists(atPath: currentDBURL.path) {
            try fileManager.removeItem(at: currentDBURL)
        }
        try fileManager.copyItem(at: backupDBURL, to: currentDBURL)
    }
    
    private func restoreImages(from directory: URL) async throws {
        let currentImagesURL = getDocumentsDirectory().appendingPathComponent("portfolio")
        let backupImagesURL = directory.appendingPathComponent("portfolio")
        if fileManager.fileExists(atPath: currentImagesURL.path) {
            try fileManager.removeItem(at: currentImagesURL)
        }
        try fileManager.copyItem(at: backupImagesURL, to: currentImagesURL)
    }
    
    private func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
