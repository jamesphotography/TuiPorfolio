import SwiftUI
import Photos

// MARK: - ImageSaver

class ImageSaver: NSObject, ObservableObject {
    @Published var isSaving = false
    @Published var saveResult: String?
    
    func saveImage(_ image: UIImage) {
        isSaving = true
        saveResult = nil
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.saveCompleted), nil)
            } else {
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.saveResult = "Save failed: No permission to access photo library"
                }
            }
        }
    }
    
    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async {
            self.isSaving = false
            if let error = error {
                self.saveResult = String(format: NSLocalizedString("Save failed: %@", comment: "Error message when saving image fails"), error.localizedDescription)
            } else {
                self.saveResult = NSLocalizedString("Image successfully saved to photo library", comment: "Success message when image is saved")
            }
        }
    }
}

// MARK: - ShareView

struct ShareView: View {
    @State private var animateButtons = false
    @StateObject private var imageSaver = ImageSaver()
    @Environment(\.dismiss) private var dismiss
    let photo: Photo
    @State private var processedImage: UIImage?
    @State private var originalImage: UIImage?
    @State private var isBirdSpecies: Bool = false
    @State private var birdNumber: Int?
    @State private var birdList: [[String]] = []
    @State private var shouldRegeneratePoster: Bool = false
    @State private var showingCopyAlert = false
    @State private var isShowingShareSheet = false
    @AppStorage("shareWithExif") private var shareWithExif = false
    @AppStorage("shareWithGPS") private var shareWithGPS = false
    @AppStorage("omitCameraBrand") private var omitCameraBrand = false
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .font(.footnote)
                }
                .padding(.leading, 15)
                .padding(.top, 15)
                
                Spacer()
            }
            
            Spacer(minLength: 20)
            
            GeometryReader { geometry in
                PosterView(photo: photo, processedImage: $processedImage, originalImage: $originalImage, isBirdSpecies: isBirdSpecies, birdNumber: birdNumber, shouldRegenerate: $shouldRegeneratePoster, saveImage: saveImage)
                    .frame(width: geometry.size.width, height: geometry.size.width)
            }
            .frame(height: UIScreen.main.bounds.width)
            
            if imageSaver.isSaving {
                ProgressView("Saving image...")
                    .padding(.top, 10)
            } else if let result = imageSaver.saveResult {
                Text(result)
                    .foregroundColor(result.contains("successfully") ? .green : .red)
                    .padding(.top, 10)
            }
            
            Spacer(minLength: 20)
            
            HStack(spacing: 20) {
                Button(action: sharePoster) {
                    VStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Poster")
                            .font(.caption2)
                    }
                    .padding()
                    .background(Color("TUIBLUE"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(imageSaver.isSaving)
                
                Button(action: saveOriginalToPhotoLibrary) {
                    VStack {
                        Image(systemName: "photo.artframe")
                        Text("Save Original")
                            .font(.caption2)
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(imageSaver.isSaving)
                
                Button(action: saveExifInfo) {
                    VStack {
                        Image(systemName: "character.textbox")
                        Text("Copy Exif")
                            .font(.caption2)
                    }
                    .padding()
                    .background(Color("Flare"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(imageSaver.isSaving)
            }
            .padding(.bottom, 20)
        }
        .alert(isPresented: $showingCopyAlert) {
            Alert(title: Text("Copy Successful"), message: Text("EXIF has been copied to the clipboard"), dismissButton: .default(Text("OK")))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onAppear {
            loadBirdList()
            checkIfBird()
            if enableBirdWatching {
                checkIfBird()
                if isBirdSpecies {
                    getBirdNumber()
                }
            }
        }
        .onChange(of: birdNumber) { oldValue, newValue in
            shouldRegeneratePoster = true
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let image = processedImage {
                ShareActivityViewController(activityItems: [image])
            }
        }
    }

    func saveImage(_ image: UIImage) {
        imageSaver.saveImage(image)
    }

    private func sharePoster() {
        if let _ = processedImage {
            isShowingShareSheet = true
        }
    }

    private func saveExifInfo() {
        var exifInfo = EXIFManager.shared.copyEXIFInfo(for: photo)
        if isBirdSpecies, let number = birdNumber {
            exifInfo += "\nBird ID:No.\(number)"
        }
        UIPasteboard.general.string = exifInfo
        showingCopyAlert = true
    }
    
    private func loadBirdList() {
        do {
            guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json") else {
                return
            }
            
            let data = try Data(contentsOf: url)
            birdList = try JSONDecoder().decode([[String]].self, from: data)
        } catch {
            // Handle error
        }
    }
    
    private func checkIfBird() {
        guard enableBirdWatching else {
            isBirdSpecies = false
            return
        }
        isBirdSpecies = birdList.contains { birdNames in
            birdNames.contains(photo.objectName)
        }
    }
    
    private func getBirdNumber() {
        guard enableBirdWatching else {
            birdNumber = nil
            return
        }
        DispatchQueue.global(qos: .background).async {
            do {
                let allObjectNames = SQLiteManager.shared.getAllObjectNames()
                let earliestPhotoTimes = SQLiteManager.shared.getEarliestPhotoTimeForBirds()
                
                let filteredBirdCounts = allObjectNames.filter { objectName, _ in
                    self.birdList.contains { birdNames in
                        birdNames.contains(objectName)
                    }
                }
                
                let sortedBirdCounts = filteredBirdCounts.compactMap { (objectName, count) -> (String, String)? in
                    if let earliestTime = earliestPhotoTimes.first(where: { $0.0 == objectName })?.1 {
                        return (objectName, earliestTime)
                    }
                    return nil
                }.sorted { $0.1 < $1.1 }
                
                if let index = sortedBirdCounts.firstIndex(where: { $0.0 == self.photo.objectName }) {
                    DispatchQueue.main.async {
                        self.birdNumber = index + 1
                    }
                }
            }
        }
    }
    
    private func saveOriginalToPhotoLibrary() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(photo.path)
        
        guard fileManager.fileExists(atPath: fullPath.path) else {
            imageSaver.saveResult = "Save failed: Original file not found"
            return
        }
        
        // 获取原始文件名
        let originalFileName = URL(fileURLWithPath: photo.title).lastPathComponent
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.originalFilename = originalFileName
                    creationRequest.addResource(with: .photo, fileURL: fullPath, options: options)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.imageSaver.saveResult = "Original image '\(originalFileName)' successfully saved to photo library"
                        } else {
                            self.imageSaver.saveResult = "Save failed: \(error?.localizedDescription ?? "Unknown error")"
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.imageSaver.saveResult = "Save failed: No permission to access photo library"
                }
            }
        }
    }
}

// MARK: - ShareActivityViewController

struct ShareActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ShareButton

struct ShareButton: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 24, weight: .semibold))
                Text(text)
                    .foregroundColor(color)
                    .font(.caption)
                    .padding(.top, 5)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color.white.opacity(0.9))
        .cornerRadius(15)
        .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 2)
    }
}

// MARK: - VisualEffectView

struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView()
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}
