import SwiftUI
import Photos

struct AlbumInfo: Identifiable {
    let id: String
    let collection: PHAssetCollection
    let photoCount: Int
}

struct ImportResultView: View {
    let result: ImportResult
    
    var body: some View {
        HStack {
            if let thumbnail = result.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
            }
            VStack(alignment: .leading) {
                Text(result.originalFileName)
                    .foregroundColor(Color("TUIBLUE"))
                Text(result.status == .success ? "Success" : "Failure")
                    .foregroundColor(result.status == .success ? .green : .red)
                if let reason = result.reason {
                    Text(NSLocalizedString(reason, comment: ""))
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct BulkImportView: View {
    @State private var selectedAlbum: PHAssetCollection?
    @State private var selectedAlbumPhotoCount: Int = 0
    @State private var isImporting = false
    @State private var progress: Float = 0
    @State private var successCount = 0
    @State private var failureCount = 0
    @State private var showResult = false
    @State private var albums: [AlbumInfo] = []
    @State private var importResults: [ImportResult] = []
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    HeadBarView(title: NSLocalizedString("Album Import", comment: ""))
                        .padding(.top, geometry.safeAreaInsets.top)
                    
                    Spacer()
                    
                    if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized || PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
                        if selectedAlbum == nil {
                            albumSelectionList
                        } else if isImporting {
                            importProgressView
                        } else if showResult {
                            importResultView
                        } else {
                            VStack {
                                Text("Selected album: \(selectedAlbum?.localizedTitle ?? "")")
                                    .foregroundColor(Color("TUIBLUE"))
                                Text("Expected import: \(selectedAlbumPhotoCount) photos")
                                    .foregroundColor(Color("TUIBLUE"))
                                    .padding(.bottom)
                                
                                startImportButton
                            }
                        }
                    } else {
                        requestAccessView
                    }
                    
                    Spacer()
                    
                    BottomBarView()
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                }
                .background(Color("BGColor").edgesIgnoringSafeArea(.all))
                .ignoresSafeArea()
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadAlbums)
    }
    
    private var albumSelectionList: some View {
        List {
            ForEach(albums) { albumInfo in
                HStack {
                    VStack(alignment: .leading) {
                        Text(albumInfo.collection.localizedTitle ?? "Untitled Album")
                            .foregroundColor(Color("TUIBLUE"))
                        Text("\(albumInfo.photoCount) photos")
                            .font(.caption)
                            .foregroundColor(Color("TUIBLUE").opacity(0.7))
                    }
                    Spacer()
                }
                .onTapGesture {
                    selectedAlbum = albumInfo.collection
                    selectedAlbumPhotoCount = albumInfo.photoCount
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Color("BGColor"))
    }
    
    private var importProgressView: some View {
        VStack {
            ProgressView("Importing...", value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color("TUIBLUE")))
            Text("\(Int(progress * 100))%")
                .foregroundColor(Color("TUIBLUE"))
            Text("Success: \(successCount), Failure: \(failureCount)")
                .foregroundColor(Color("TUIBLUE"))
        }
        .padding()
        .background(Color("BGColor"))
    }
    
    private var importResultView: some View {
        VStack {
            HStack {
                Text("Import Completed")
                    .foregroundColor(Color("TUIBLUE"))
                Spacer()
                Text("Successfully imported: \(successCount)")
                    .foregroundColor(Color(.blue))
                Spacer()
                Text("Failed to import: \(failureCount)")
                    .foregroundColor(Color("Flare"))
            }
            .padding(.horizontal)
            .font(.headline)
            
            List {
                Section(header: Text("Successful Imports").foregroundColor(Color("TUIBLUE"))) {
                    ForEach(importResults.filter { $0.status == .success }) { result in
                        ImportResultView(result: result)
                    }
                }
                
                Section(header: Text("Failed Imports").foregroundColor(Color("TUIBLUE"))) {
                    ForEach(importResults.filter { $0.status == .failure }) { result in
                        ImportResultView(result: result)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .background(Color("BGColor"))
            
            Button("Import More") {
                resetImportState()
            }
            .foregroundColor(.white)
            .padding()
            .background(Color("TUIBLUE"))
            .cornerRadius(10)
        }
        .background(Color("BGColor"))
    }
    
    private var startImportButton: some View {
        Button("Start Import") {
            startImport()
        }
        .foregroundColor(.white)
        .padding()
        .background(Color("TUIBLUE"))
        .cornerRadius(10)
    }
    
    private var requestAccessView: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("Photo Library Access Required", comment: "Photo library access required title"))
                .font(.title)
                .fontWeight(.bold)
            
            Text(NSLocalizedString("Please grant access to your photo library in Settings.", comment: "Instruct user to grant access in settings"))
                .multilineTextAlignment(.center)
            
            Text(NSLocalizedString("We need access to your photo library so you can select individual photos or entire albums to import into your portfolio. We read metadata (such as capture date, location, and camera information) from the selected photos, but we do not modify or delete your original photos. This allows us to organize your portfolio efficiently and provide features like timeline view and location-based browsing. You can manage or delete imported photos within the app at any time. We do not share your photos or metadata with third parties.", comment: "Detailed explanation of photo library usage"))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding()
            
            Button(action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                Text(NSLocalizedString("Open Settings", comment: "Open settings button"))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color("BGColor"))
    }
    
    private func loadAlbums() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    let albumOptions = PHFetchOptions()
                    albumOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
                    let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumOptions)
                    self.albums = []
                    userAlbums.enumerateObjects { (collection, index, _) in
                        let photoOptions = PHFetchOptions()
                        photoOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
                        let photoCount = PHAsset.fetchAssets(in: collection, options: photoOptions).count
                        let albumInfo = AlbumInfo(id: collection.localIdentifier, collection: collection, photoCount: photoCount)
                        self.albums.append(albumInfo)
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func startImport() {
        guard let album = selectedAlbum else { return }
        isImporting = true
        errorMessage = ""
        
        BulkImportManager.shared.importPhotos(from: album) { currentProgress, success, failure in
            DispatchQueue.main.async {
                self.progress = currentProgress
                self.successCount = success
                self.failureCount = failure
            }
        } completionHandler: { results in
            DispatchQueue.main.async {
                self.importResults = results
                self.isImporting = false
                self.showResult = true
                
                // Set the error message if there are any failures
                if let firstFailure = results.first(where: { $0.status == .failure }) {
                    self.errorMessage = firstFailure.reason ?? "Unknown error occurred"
                }
                if self.successCount > 0 {
                    UserDefaults.standard.set(false, forKey: "isFirstLaunch")
                    
                    // Post a notification that data has been updated
                    NotificationCenter.default.post(name: .photoDataUpdated, object: nil)
                }
            }
        }
    }
    
    private func resetImportState() {
        selectedAlbum = nil
        selectedAlbumPhotoCount = 0
        isImporting = false
        progress = 0
        successCount = 0
        failureCount = 0
        showResult = false
        importResults = []
        errorMessage = ""
    }
}

struct BulkImportView_Previews: PreviewProvider {
    static var previews: some View {
        BulkImportView()
    }
}

// Add this extension at the end of the file
extension Notification.Name {
    static let photoDataUpdated = Notification.Name("photoDataUpdated")
}
