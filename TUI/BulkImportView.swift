import SwiftUI
import Photos

struct AlbumInfo: Identifiable {
    let id: String
    let collection: PHAssetCollection
    let photoCount: Int
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
            Text("Import Completed")
                .font(.title)
                .foregroundColor(Color("TUIBLUE"))
            Text("Successfully imported: \(successCount)")
                .foregroundColor(Color("TUIBLUE"))
            Text("Failed to import: \(failureCount)")
                .foregroundColor(Color("TUIBLUE"))
            
            List {
                Section(header: Text("Successful Imports").foregroundColor(Color("TUIBLUE"))) {
                    ForEach(importResults.filter { $0.status == .success }) { result in
                        Text(result.originalFileName)
                            .foregroundColor(Color("TUIBLUE"))
                    }
                }
                
                Section(header: Text("Failed Imports").foregroundColor(Color("TUIBLUE"))) {
                    ForEach(importResults.filter { $0.status == .failure }) { result in
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
                                if let reason = result.reason {
                                    Text(NSLocalizedString(reason, comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            
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
        VStack {
            Text("Photo Library Access Required")
                .font(.title)
                .foregroundColor(Color("TUIBLUE"))
            Text("Please grant access to your photo library in Settings.")
                .multilineTextAlignment(.center)
                .padding()
                .foregroundColor(Color("TUIBLUE"))
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            .foregroundColor(.white)
            .padding()
            .background(Color("TUIBLUE"))
            .cornerRadius(10)
        }
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
