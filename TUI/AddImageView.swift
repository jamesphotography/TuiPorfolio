import SwiftUI
import Photos
import SQLite3

struct AddImageView: View {
    @State private var image: Image? = nil
    @State private var imageName: String = ""
    @State private var cameraInfo: String = ""
    @State private var lensInfo: String = ""
    @State private var captureDate: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var country: String = ""
    @State private var area: String = ""
    @State private var locality: String = ""
    @State private var starRating: Int = 0
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage? = nil
    @State private var saveMessage: String = ""
    @State private var showingSaveMessage = false
    @State private var exposureTime: Double = 0.0
    @State private var fNumber: Double = 0.0
    @State private var focalLenIn35mmFilm: Double = 0.0
    @State private var focalLength: Double = 0.0
    @State private var ISOSPEEDRatings: Int = 0
    @State private var altitude: Double = 0.0
    @State private var objectName: String = ""
    @State private var caption: String = ""
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToDetailView = false
    @State private var savedPhoto: Photo?
    @State private var navigateToBulkImport = false
    
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    HeadBarView(title: NSLocalizedString("Add Photo to Portfolio", comment: ""))
                        .padding(.top, geometry.safeAreaInsets.top)
                    
                    ScrollView {
                        VStack {
                            Spacer()
                            
                            if let image = image {
                                Text("\(imageName)")
                                    .font(.caption)
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width * 0.7)
                                    .padding()
                                
                                ReviewView(cameraInfo: $cameraInfo, lensInfo: $lensInfo, captureDate: $captureDate,
                                           country: $country, area: $area, locality: $locality, starRating: $starRating,
                                           objectName: $objectName, caption: $caption, focalLength: $focalLength,
                                           fNumber: $fNumber, exposureTime: $exposureTime, isoSpeedRatings: $ISOSPEEDRatings)
                                
                                Button(action: {
                                    saveImage()
                                }) {
                                    Text("Add to Portfolio")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color("TUIBLUE"))
                                        .cornerRadius(10)
                                }
                                .padding()
                            } else {
                                VStack {
                                    Spacer()
                                    Button(action: {
                                        self.showingImagePicker = true
                                    }) {
                                        ButtonContent(
                                            icon: "photo.badge.plus.fill",
                                            text: NSLocalizedString("Add one image", comment: "Button to add a single image"),
                                            color: Color("TUIBLUE")
                                        )
                                    }
                                    .padding(30)
                                    Spacer()
                                    Button(action: {
                                        self.navigateToBulkImport = true
                                    }) {
                                        ButtonContent(
                                            icon: "rectangle.stack.badge.plus",
                                            text: NSLocalizedString("Bulk Import", comment: "Button to import multiple images"),
                                            color: Color("Flare")
                                        )
                                    }
                                    .padding(30)
                                    Spacer()
                                    Text(NSLocalizedString("Note: Apple GPS lookup requires an active internet. The process may be delayed due to a limit of one queries per 2 seconds. Please patient during bulk imports.", comment: "Expanded explanation for GPS reverse lookup limitations and requirements"))
                                                                            .font(.caption)
                                                                            .foregroundColor(.secondary)
                                                                            .multilineTextAlignment(.leading)
                                                                            .padding(.horizontal)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color("BGColor"))
                        .foregroundColor(Color("TUIBLUE"))
                    }
                    
                    BottomBarView()
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                }
                .background(Color("BGColor").edgesIgnoringSafeArea(.all))
                .ignoresSafeArea()
                .sheet(isPresented: $showingImagePicker, onDismiss: loadImage) {
                    ImagePicker(image: self.$inputImage, imageName: self.$imageName, cameraInfo: self.$cameraInfo, lensInfo: self.$lensInfo, captureDate: self.$captureDate, latitude: self.$latitude, longitude: self.$longitude, country: self.$country, area: self.$area,locality: self.$locality, starRating: self.$starRating, exposureTime: self.$exposureTime, fNumber: self.$fNumber, focalLenIn35mmFilm: self.$focalLenIn35mmFilm, focalLength: self.$focalLength, ISOSPEEDRatings: self.$ISOSPEEDRatings, altitude: self.$altitude, objectName: self.$objectName, caption: self.$caption)
                }
                .alert(isPresented: $showingSaveMessage) {
                    Alert(title: Text("Save Status"), message: Text(saveMessage), dismissButton: .default(Text("OK"), action: {
                        if savedPhoto != nil {
                            navigateToDetailView = true
                        } else {
                            dismiss()
                        }
                    }))
                }
                .navigationDestination(isPresented: $navigateToDetailView) {
                    if let savedPhoto = savedPhoto {
                        DetailView(photos: [savedPhoto], initialIndex: 0) { _ in
                            self.navigateToDetailView = false
                        }
                    }
                }
                .navigationDestination(isPresented: $navigateToBulkImport) {
                    BulkImportView()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    func loadImage() {
        guard let inputImage = inputImage else { return }
        image = Image(uiImage: inputImage)
    }
    
    func saveImage() {
        guard let inputImage = inputImage else {
            return
        }
        
        guard let imageData = inputImage.jpegData(compressionQuality: 1.0) else {
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let addTimestamp = dateFormatter.string(from: Date())
        
        let inputDateFormatter = DateFormatter()
        inputDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = inputDateFormatter.date(from: captureDate) else {
            saveMessage = NSLocalizedString("Failed to save image: Failed to parse capture date", comment: "Error message when trying to save a no capture date photo")
            showingSaveMessage = true
            return
        }
        
        let formattedCaptureDate = dateFormatter.string(from: date)
        let fileNamePrefix = URL(fileURLWithPath: imageName).deletingPathExtension().lastPathComponent
        
        if SQLiteManager.shared.isPhotoExists(captureDate: formattedCaptureDate, fileNamePrefix: fileNamePrefix) {
            saveMessage = NSLocalizedString("Photo already exists", comment: "Error message when trying to save a duplicate photo")
            showingSaveMessage = true
            return
        }
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let year = yearFormatter.string(from: date)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        let month = monthFormatter.string(from: date)
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let day = dayFormatter.string(from: date)
        
        let portfolioDirectory = getDocumentsDirectory().appendingPathComponent("portfolio").appendingPathComponent(year).appendingPathComponent(month).appendingPathComponent(day)
        
        do {
            try FileManager.default.createDirectory(at: portfolioDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            saveMessage = "Failed to create portfolio directory: \(error)"
            showingSaveMessage = true
            return
        }
        
        let uuid = UUID().uuidString
        let fileName = "\(uuid).jpg"
        let fileURL = portfolioDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            let title = URL(fileURLWithPath: imageName).deletingPathExtension().lastPathComponent
            imageName = fileName
            saveMessage = "\(title) Image saved successfully"
            
            let thumbnail100 = generateThumbnail(for: inputImage, size: CGSize(width: 100, height: 100))
            let thumbnail350 = generateThumbnail(for: inputImage, size: CGSize(width: 350, height: 350))
            
            let thumbnail100Name = "\(uuid)_thumb100.jpg"
            let thumbnail350Name = "\(uuid)_thumb350.jpg"
            let thumbnail100Path = portfolioDirectory.appendingPathComponent(thumbnail100Name)
            let thumbnail350Path = portfolioDirectory.appendingPathComponent(thumbnail350Name)
            
            try thumbnail100?.jpegData(compressionQuality: 1.0)?.write(to: thumbnail100Path)
            try thumbnail350?.jpegData(compressionQuality: 1.0)?.write(to: thumbnail350Path)
            
            let relativePath = fileURL.path.replacingOccurrences(of: getDocumentsDirectory().path, with: "")
            let relativeThumbnail100Path = thumbnail100Path.path.replacingOccurrences(of: getDocumentsDirectory().path, with: "")
            let relativeThumbnail350Path = thumbnail350Path.path.replacingOccurrences(of: getDocumentsDirectory().path, with: "")
            
            let success = SQLiteManager.shared.addPhoto(
                id: uuid,
                title: title,
                path: relativePath,
                thumbnailPath100: relativeThumbnail100Path,
                thumbnailPath350: relativeThumbnail350Path,
                starRating: starRating,
                country: country,
                area: area,
                locality: locality,
                dateTimeOriginal: formattedCaptureDate,
                addTimestamp: addTimestamp,
                lensModel: lensInfo,
                model: cameraInfo,
                exposureTime: exposureTime,
                fNumber: fNumber,
                focalLenIn35mmFilm: focalLenIn35mmFilm,
                focalLength: focalLength,
                ISOSPEEDRatings: ISOSPEEDRatings,
                altitude: altitude,
                latitude: Double(latitude) ?? 0.0,
                longitude: Double(longitude) ?? 0.0,
                objectName: objectName,
                caption: caption
            )
            
            if success {
                SQLiteManager.shared.invalidateCache()
                BirdCountCache.shared.clear()
                
                savedPhoto = Photo(
                    id: uuid,
                    title: title,
                    path: relativePath,
                    thumbnailPath100: relativeThumbnail100Path,
                    thumbnailPath350: relativeThumbnail350Path,
                    starRating: starRating,
                    country: country,
                    area: area,
                    locality: locality,
                    dateTimeOriginal: formattedCaptureDate,
                    addTimestamp: addTimestamp,
                    lensModel: lensInfo,
                    model: cameraInfo,
                    exposureTime: exposureTime,
                    fNumber: fNumber,
                    focalLenIn35mmFilm: focalLenIn35mmFilm,
                    focalLength: focalLength,
                    ISOSPEEDRatings: ISOSPEEDRatings,
                    altitude: altitude,
                    latitude: Double(latitude) ?? 0.0,
                    longitude: Double(longitude) ?? 0.0,
                    objectName: objectName,
                    caption: caption
                )
                deleteTemporaryFile()
            } else {
                saveMessage = "Failed to save photo to SQLite"
            }
            
        } catch {
            saveMessage = "Failed to save image: \(error)"
        }
        UserDefaults.standard.set(false, forKey: "isFirstLaunch")
        showingSaveMessage = true
    }
    
    func generateThumbnail(for image: UIImage, size: CGSize) -> UIImage? {
        let aspectWidth = size.width / image.size.width
        let aspectHeight = size.height / image.size.height
        let aspectRatio = max(aspectWidth, aspectHeight)
        
        let newSize = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { _ in
            let x = (newSize.width - size.width) / 2
            let y = (newSize.height - size.height) / 2
            image.draw(in: CGRect(x: -x, y: -y, width: newSize.width, height: newSize.height))
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func deleteTemporaryFile() {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(imageName)
        
        do {
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
        } catch {
            print("Failed to delete temporary file: \(error.localizedDescription)")
        }
    }
}

struct ButtonContent: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 60))
            Text(text)
                .font(.headline)
        }
        .foregroundColor(.white)
        .frame(width: 200, height: 200)
        .background(color)
        .cornerRadius(10)
    }
}

struct AddImageView_Previews: PreviewProvider {
    static var previews: some View {
        AddImageView()
    }
}
