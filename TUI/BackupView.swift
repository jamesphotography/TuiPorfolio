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
    @State private var showingRestartAlert = false
    @State private var animatedProgress: Double = 0.0
    @State private var backupToShare: BackupFile?
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""
    @State private var backupToDelete: BackupFile?
    @State private var showingDeleteConfirmation = false

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
        .onAppear(perform: loadExistingBackups)
        .alert(isPresented: $showingRestartAlert) {
            Alert(
                title: Text("Restore Completed"),
                message: Text("Please exit Tui and restart the app to refresh the data."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Confirm Delete"),
                message: Text("Are you sure you want to delete this backup? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let backup = backupToDelete {
                        deleteBackup(backup)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(item: $backupToShare) { backup in
            ActivityViewController(activityItems: [backup.url])
        }
    }
    
    private var backupSection: some View {
        VStack(spacing: 15) {
            Text("Create New Backup")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("User: \(userName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: performBackup) {
                Text("Create Backup")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isBackingUp || isRestoring || userName.isEmpty)
            
            if isBackingUp || isRestoring {
                ProgressView(value: animatedProgress) {
                    Text("\(isBackingUp ? "Backing up" : "Restoring")... \(Int(animatedProgress * 100))%")
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
            Text("Existing Backups")
                .font(.title2)
                .fontWeight(.bold)
            
            if existingBackups.isEmpty {
                Text("No backups found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(existingBackups) { backup in
                    HStack {
                        Image(systemName: selectedBackup == backup ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(.blue)
                            .onTapGesture {
                                selectedBackup = backup
                            }
                        
                        VStack(alignment: .leading) {
                            Text(backup.url.lastPathComponent)
                                .font(.subheadline)
                            HStack {
                                Text("Date: \(backup.creationDate, formatter: itemFormatter)")
                                Spacer()
                                Text("Size: \(backup.size)")
                            }
                            Text("User: \(backup.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            print("Share button tapped for: \(backup.url.path)")
                            self.backupToShare = backup
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            print("Delete button tapped for: \(backup.url.lastPathComponent)")
                            backupToDelete = backup
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            
            Divider()
            
            Text("Restore")
                .font(.title2)
                .fontWeight(.bold)
            
            if let selectedBackup = selectedBackup {
                Text("Selected backup: \(selectedBackup.url.lastPathComponent)")
                    .foregroundColor(.secondary)
                
                Button(action: { performRestore(from: selectedBackup.url) }) {
                    Text("Start Restore")
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isBackingUp || isRestoring)
            } else {
                Text("Select a backup from the list above")
                    .foregroundColor(.secondary)
            }
            
            if isRestoring {
                ProgressView()
                Text("Restoring...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
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
            showError("Failed to load backups: \(error.localizedDescription)")
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
                
                // Remove the deleted backup from the existingBackups array
                existingBackups.removeAll { $0.id == backup.id }
                print("Backup removed from list")
                
                // Refresh the backup list
                loadExistingBackups()
            } else {
                print("Backup file does not exist at path")
                showError("Backup file not found")
            }
            
            if selectedBackup == backup {
                selectedBackup = nil
                print("Selected backup reset")
            }
        } catch {
            print("Failed to delete backup: \(error.localizedDescription)")
            showError("Failed to delete backup: \(error.localizedDescription)")
        }
    }
    
    private func performBackup() {
        guard !userName.isEmpty else {
            showError("Username is not set. Please set a username in Settings.")
            return
        }
        
        Task {
            do {
                isBackingUp = true
                backupStatus = "Creating backup..."
                let backupURL = try await BackupManager.shared.createBackup(username: userName) { progress in
                    DispatchQueue.main.async {
                        self.backupProgress = progress
                    }
                }
                backupStatus = "Backup created at: \(backupURL.lastPathComponent)"
                loadExistingBackups()
            } catch {
                print("Backup failed: \(error)")
                showError("Backup failed: \(error.localizedDescription)")
            }
            isBackingUp = false
        }
    }
    
    private func performRestore(from backupURL: URL) {
        Task {
            do {
                isRestoring = true
                backupStatus = "Restoring..."
                try await BackupManager.shared.restoreBackup(from: backupURL) { progress in
                    DispatchQueue.main.async {
                        self.backupProgress = progress
                    }
                }
                backupStatus = "Restore completed successfully"
                
                // Update the userName in the view
                DispatchQueue.main.async {
                    self.userName = UserDefaults.standard.string(forKey: "userName") ?? "Unknown"
                }
                
                showingRestartAlert = true  // Show restart reminder
            } catch {
                print("Restore failed: \(error)")
                showError("Restore failed: \(error.localizedDescription)")
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
