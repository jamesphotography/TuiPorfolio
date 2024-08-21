import Foundation
import ZipArchive

class BackupManager {
    static let shared = BackupManager()
    private let fileManager = FileManager.default
    
    private let defaultUsername = NSLocalizedString("James", comment: "Default username for factory reset")
    
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
            await MainActor.run { progressUpdate(0.1) }
            
            try await backupDatabase(to: tempBackupDirURL)
            await MainActor.run { progressUpdate(0.4) }
            
            try await backupImages(to: tempBackupDirURL)
            await MainActor.run { progressUpdate(0.7) }
            
            guard SSZipArchive.createZipFile(atPath: backupURL.path, withContentsOfDirectory: tempBackupDirURL.path) else {
                throw BackupError.failedToCreateZip
            }
            await MainActor.run { progressUpdate(1.0) }

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
            await MainActor.run { progressUpdate(0.1) }
            
            guard SSZipArchive.unzipFile(atPath: backupURL.path, toDestination: tempRestoreDirURL.path) else {
                throw BackupError.failedToUnzip
            }
            await MainActor.run { progressUpdate(0.3) }
            
            let backupFileName = backupURL.lastPathComponent
            let username = extractUsername(from: backupFileName)
            
            await MainActor.run {
                if backupURL.lastPathComponent.starts(with: "DefaultBackup_") {
                    setDefaultSettings()
                } else {
                    UserDefaults.standard.set(username, forKey: "userName")
                }
            }
            
            try await restoreDatabase(from: tempRestoreDirURL)
            await MainActor.run { progressUpdate(0.5) }
            
            try await restoreImages(from: tempRestoreDirURL)
            await MainActor.run { progressUpdate(0.7) }
            
            print("Backup successfully restored")
            await MainActor.run { progressUpdate(1.0) }
        } catch {
            print("Restore failed: \(error.localizedDescription)")
            throw error
        }
        UserDefaults.standard.set(false, forKey: "isFirstLaunch")
    }
    
    private func extractUsername(from fileName: String) -> String {
        if fileName.starts(with: "DefaultBackup_") {
            return defaultUsername
        }
        
        let components = fileName.split(separator: "_")
        if components.count >= 3 {
            return String(components[2].dropLast(4)) // Remove ".zip" extension
        }
        return defaultUsername
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
    
    func getDefaultBackupURL() -> URL? {
        return Bundle.main.url(forResource: "JamesTuiPortfolio", withExtension: "zip")
    }

    func copyDefaultBackupIfNeeded() {
        guard let defaultBackupURL = getDefaultBackupURL() else {
            print("Default backup not found in bundle")
            return
        }

        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent("DefaultBackup_JamesTuiPortfolio.zip")

        if !fileManager.fileExists(atPath: destinationURL.path) {
            do {
                try fileManager.copyItem(at: defaultBackupURL, to: destinationURL)
                print("Default backup copied to documents directory")
            } catch {
                print("Failed to copy default backup: \(error)")
            }
        }
    }
    
    func restoreDefaultBackup(progressUpdate: @escaping (Double) -> Void) async throws {
        guard getDefaultBackupURL() != nil else {
            throw BackupError.invalidBackup
        }
        
        copyDefaultBackupIfNeeded()
        
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let copiedDefaultBackupURL = documentsURL.appendingPathComponent("DefaultBackup_JamesTuiPortfolio.zip")
        
        try await restoreBackup(from: copiedDefaultBackupURL) { progress in
            Task { @MainActor in
                progressUpdate(progress)
            }
        }
        
        await MainActor.run {
            setDefaultSettings()
        }
        
        try? fileManager.removeItem(at: copiedDefaultBackupURL)
        
        UserDefaults.standard.set(false, forKey: "isFirstLaunch")
    }
    
    private func setDefaultSettings() {
        UserDefaults.standard.set(defaultUsername, forKey: "userName")
        UserDefaults.standard.set(true, forKey: "sortByShootingTime")
        UserDefaults.standard.set(true, forKey: "enableBirdWatching")
        UserDefaults.standard.set(true, forKey: "shareWithExif")
        UserDefaults.standard.set(true, forKey: "shareWithGPS")
        UserDefaults.standard.set(true, forKey: "omitCameraBrand")
    }
}
