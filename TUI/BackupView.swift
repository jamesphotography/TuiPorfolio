import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @AppStorage("userName") private var userName = "Jo"
    @State private var backupStatus: String?
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var backupProgress: Double = 0.0
    @State private var existingBackups: [BackupFile] = []
    @State private var selectedBackup: BackupFile?
    @State private var showingRestoreSuccessAlert = false
    @State private var animatedProgress: Double = 0.0
    @State private var backupToShare: BackupFile?
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""
    @State private var backupToDelete: BackupFile?
    @State private var showingDeleteConfirmation = false
    @State private var defaultBackup: BackupFile?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: NSLocalizedString("Backup & Restore", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 20) {
                        backupSection
                        existingBackupsAndRestoreSection
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color("BGColor"))
                }
                
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            loadExistingBackups()
            loadDefaultBackup()
        }
        .alert(isPresented: $showingRestoreSuccessAlert) {
            Alert(
                title: Text(NSLocalizedString("Restore Completed", comment: "")),
                message: Text(NSLocalizedString("The backup has been successfully restored. Please restart the app to apply the changes.", comment: "")),
                primaryButton: .default(Text(NSLocalizedString("Restart Now", comment: ""))) {
                    exit(0)
                },
                secondaryButton: .cancel(Text(NSLocalizedString("Later", comment: "")))
            )
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text(NSLocalizedString("Error", comment: "")),
                message: Text(errorMessage),
                dismissButton: .default(Text(NSLocalizedString("OK", comment: "")))
            )
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text(NSLocalizedString("Confirm Delete", comment: "")),
                message: Text(NSLocalizedString("Are you sure you want to delete this backup? This action cannot be undone.", comment: "")),
                primaryButton: .destructive(Text(NSLocalizedString("Delete", comment: ""))) {
                    if let backup = backupToDelete {
                        deleteBackup(backup)
                    }
                },
                secondaryButton: .cancel(Text(NSLocalizedString("Cancel", comment: "")))
            )
        }
        .sheet(item: $backupToShare) { backup in
            ActivityViewController(activityItems: [backup.url])
        }
    }
    
    private var backupSection: some View {
        VStack(spacing: 15) {
            Text(NSLocalizedString("Create New Backup", comment: ""))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(NSLocalizedString("User: ", comment: "") + userName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: performBackup) {
                Text(NSLocalizedString("Create Backup", comment: ""))
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isBackingUp || isRestoring || userName.isEmpty)
            
            if isBackingUp || isRestoring {
                ProgressView(value: animatedProgress) {
                    Text(String(format: NSLocalizedString("%@... %d%%", comment: ""), isBackingUp ? NSLocalizedString("Backing up", comment: "") : NSLocalizedString("Restoring", comment: ""), Int(animatedProgress * 100)))
                }
                .progressViewStyle(LinearProgressViewStyle())
            }
            
            if let status = backupStatus {
                Text(status)
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: backupProgress) { oldValue, newValue in
             withAnimation {
                 animatedProgress = newValue
             }
         }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
    
    private var existingBackupsAndRestoreSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(NSLocalizedString("Existing Backups", comment: ""))
                .font(.title2)
                .fontWeight(.bold)
            
            if existingBackups.isEmpty && defaultBackup == nil {
                Text(NSLocalizedString("No backups found", comment: ""))
                    .foregroundColor(.secondary)
            } else {
                if let defaultBackup = defaultBackup {
                    backupRow(for: defaultBackup, isDefault: true)
                }
                
                ForEach(existingBackups) { backup in
                    backupRow(for: backup, isDefault: false)
                }
            }
            
            Divider()
            
            Text(NSLocalizedString("Restore", comment: ""))
                .font(.title2)
                .fontWeight(.bold)
            
            if let selectedBackup = selectedBackup {
                Text(NSLocalizedString("Selected backup: ", comment: "") + selectedBackup.url.lastPathComponent)
                    .foregroundColor(.secondary)
                
                Button(action: { performRestore(from: selectedBackup.url) }) {
                    Text(NSLocalizedString("Start Restore", comment: ""))
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isBackingUp || isRestoring)
            } else {
                Text(NSLocalizedString("Select a backup from the list above", comment: ""))
                    .foregroundColor(.secondary)
            }
            
            if isRestoring {
                ProgressView()
                Text(NSLocalizedString("Restoring...", comment: ""))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
    
    private func backupRow(for backup: BackupFile, isDefault: Bool) -> some View {
        HStack {
            Image(systemName: selectedBackup == backup ? "largecircle.fill.circle" : "circle")
                .foregroundColor(.blue)
                .onTapGesture {
                    selectedBackup = backup
                }
            
            VStack(alignment: .leading) {
                Text(isDefault ? NSLocalizedString("Default Backup (Factory Reset)", comment: "") : backup.url.lastPathComponent)
                    .font(.subheadline)
                HStack {
                    Text(NSLocalizedString("Date: ", comment: "") + itemFormatter.string(from: backup.creationDate))
                    Spacer()
                    Text(NSLocalizedString("Size: ", comment: "") + backup.size)
                }
                Text(NSLocalizedString("User: ", comment: "") + backup.username)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isDefault {
                Button(action: {
                    self.backupToShare = backup
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    backupToDelete = backup
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 5)
    }
    
    private func loadExistingBackups() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to get documents directory")
            return
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            existingBackups = fileURLs.filter { $0.pathExtension == "zip" && $0.lastPathComponent.starts(with: "TuiBackup_") }
                .compactMap { url -> BackupFile? in
                    let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                    let creationDate = attributes?[.creationDate] as? Date ?? Date()
                    let size = attributes?[.size] as? Int64 ?? 0
                    let components = url.lastPathComponent.split(separator: "_")
                    let username = components.count > 2 ? String(components[2].dropLast(4)) : "Unknown"
                    return BackupFile(url: url, creationDate: creationDate, size: formatFileSize(size), username: username)
                }
                .sorted { $0.creationDate > $1.creationDate }
        } catch {
            print("Failed to get directory contents: \(error.localizedDescription)")
            showError(NSLocalizedString("Failed to load backups: ", comment: "") + error.localizedDescription)
        }
    }
    
    private func loadDefaultBackup() {
        if let defaultBackupURL = BackupManager.shared.getDefaultBackupURL() {
            let attributes = try? FileManager.default.attributesOfItem(atPath: defaultBackupURL.path)
            let creationDate = attributes?[.creationDate] as? Date ?? Date()
            let size = attributes?[.size] as? Int64 ?? 0
            defaultBackup = BackupFile(url: defaultBackupURL, creationDate: creationDate, size: formatFileSize(size), username: "James")
        }
    }
    
    private func deleteBackup(_ backup: BackupFile) {
        let fileManager = FileManager.default
        print("Attempting to delete backup: \(backup.url.lastPathComponent)")
        print("Full path: \(backup.url.path)")
        
        do {
            if fileManager.fileExists(atPath: backup.url.path) {
                try fileManager.removeItem(at: backup.url)
                print("Backup file successfully deleted")
                
                existingBackups.removeAll { $0.id == backup.id }
                print("Backup removed from list")
                
                loadExistingBackups()
            } else {
                print("Backup file does not exist at path")
                showError(NSLocalizedString("Backup file not found", comment: ""))
            }
            
            if selectedBackup == backup {
                selectedBackup = nil
                print("Selected backup reset")
            }
        } catch {
            print("Failed to delete backup: \(error.localizedDescription)")
            showError(NSLocalizedString("Failed to delete backup: ", comment: "") + error.localizedDescription)
        }
    }
    
    private func performBackup() {
        guard !userName.isEmpty else {
            showError(NSLocalizedString("Username is not set. Please set a username in Settings.", comment: ""))
            return
        }
        
        Task {
            do {
                isBackingUp = true
                backupStatus = NSLocalizedString("Creating backup...", comment: "")
                let backupURL = try await BackupManager.shared.createBackup(username: userName) { progress in
                    DispatchQueue.main.async {
                        self.backupProgress = progress
                    }
                }
                backupStatus = NSLocalizedString("Backup created at: ", comment: "") + backupURL.lastPathComponent
                loadExistingBackups()
            } catch {
                print("Backup failed: \(error)")
                showError(NSLocalizedString("Backup failed: ", comment: "") + error.localizedDescription)
            }
            isBackingUp = false
        }
    }
    
    private func performRestore(from backupURL: URL) {
        Task {
            do {
                isRestoring = true
                backupStatus = NSLocalizedString("Restoring...", comment: "")
                
                if backupURL == BackupManager.shared.getDefaultBackupURL() {
                    try await BackupManager.shared.restoreDefaultBackup { progress in
                        DispatchQueue.main.async {
                            self.backupProgress = progress
                        }
                    }
                } else {
                    try await BackupManager.shared.restoreBackup(from: backupURL) { progress in
                        DispatchQueue.main.async {
                            self.backupProgress = progress
                        }
                    }
                }
                
                // 在这里添加设置 isFirstLaunch 为 false 的代码
                UserDefaults.standard.set(false, forKey: "isFirstLaunch")
                
                backupStatus = NSLocalizedString("Restore completed successfully", comment: "")
                
                DispatchQueue.main.async {
                    self.userName = UserDefaults.standard.string(forKey: "userName") ?? NSLocalizedString("Unknown", comment: "")
                    self.showingRestoreSuccessAlert = true
                }
            } catch {
                print("Restore failed: \(error)")
                showError(NSLocalizedString("Restore failed: ", comment: "") + error.localizedDescription)
            }
            isRestoring = false
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
}

struct BackupFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let creationDate: Date
    let size: String
    let username: String
    
    static func == (lhs: BackupFile, rhs: BackupFile) -> Bool {
        return lhs.id == rhs.id
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        print("Creating ActivityViewController with items: \(activityItems)")
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct BackupView_Previews: PreviewProvider {
    static var previews: some View {
        BackupView()
    }
}
