import SwiftUI
import Photos
import SQLite3
import UIKit
import ImageIO
import UniformTypeIdentifiers

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
    
    // 新增的状态变量
    @State private var receivedImageURL: URL?
    @State private var isProcessingReceivedImage = false
    
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
                                    .font(.title3)
                                    .fontWeight(.thin)
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width * 0.9)
                                    .cornerRadius(5)
                                    .shadow(radius: 3)
                                
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
                                        .cornerRadius(5)
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
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
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
                        DetailView(photo: savedPhoto)
                    }
                }
                .navigationDestination(isPresented: $navigateToBulkImport) {
                    BulkImportView()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let url = receivedImageURL {
                processReceivedImage(url: url)
            }
        }
    }
    
    func loadImage() {
        guard let inputImage = inputImage else { return }
        image = Image(uiImage: inputImage)
    }
    
    func processReceivedImage(url: URL) {
        isProcessingReceivedImage = true
        
        guard let imageData = try? Data(contentsOf: url),
              let uiImage = UIImage(data: imageData) else {
            saveMessage = "Failed to load image from URL"
            showingSaveMessage = true
            isProcessingReceivedImage = false
            return
        }
        
        inputImage = uiImage
        image = Image(uiImage: uiImage)
        imageName = url.lastPathComponent
        
        if let source = CGImageSourceCreateWithData(imageData as CFData, nil) {
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                if let exif = properties["{Exif}"] as? [String: Any] {
                    captureDate = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String ?? ""
                    exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? Double ?? 0.0
                    fNumber = exif[kCGImagePropertyExifFNumber as String] as? Double ?? 0.0
                    focalLenIn35mmFilm = exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Double ?? 0.0
                    focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double ?? 0.0
                    ISOSPEEDRatings = exif[kCGImagePropertyExifISOSpeedRatings as String] as? Int ?? 0
                }
                if let tiff = properties["{TIFF}"] as? [String: Any] {
                    cameraInfo = tiff[kCGImagePropertyTIFFModel as String] as? String ?? ""
                    lensInfo = tiff[kCGImagePropertyTIFFMake as String] as? String ?? ""
                }
                if let gps = properties["{GPS}"] as? [String: Any] {
                    latitude = String(gps[kCGImagePropertyGPSLatitude as String] as? Double ?? 0.0)
                    longitude = String(gps[kCGImagePropertyGPSLongitude as String] as? Double ?? 0.0)
                    altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double ?? 0.0
                }
            }
        }
        
        isProcessingReceivedImage = false
    }
    
    func printEXIFInfo(from imageData: Data) {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            print("Failed to create image source")
            return
        }
        
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            print("No metadata found")
            return
        }
        
        if let exif = metadata["{Exif}"] as? [String: Any] {
            print("EXIF data:")
            for (key, value) in exif {
                print("\(key): \(value)")
            }
        } else {
            print("No EXIF data found")
        }
        
        if let tiff = metadata["{TIFF}"] as? [String: Any] {
            print("TIFF data:")
            for (key, value) in tiff {
                print("\(key): \(value)")
            }
        }
        
        if let gps = metadata["{GPS}"] as? [String: Any] {
            print("GPS data:")
            for (key, value) in gps {
                print("\(key): \(value)")
            }
        }
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
    
    func saveImage() {
        guard let inputImage = inputImage else {
            saveMessage = "No input image"
            showingSaveMessage = true
            return
        }
        
        guard let imageData = inputImage.jpegData(compressionQuality: 1.0) else {
            saveMessage = "Failed to get image data"
            showingSaveMessage = true
            return
        }
        
//        print("Original image EXIF:")
//        printEXIFInfo(from: imageData)
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            saveMessage = "Failed to create image source"
            showingSaveMessage = true
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
        
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            saveMessage = "Failed to create image destination"
            showingSaveMessage = true
            return
        }
        
        let originalProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        
        var newProps = originalProps
        var exifDict = (newProps[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        exifDict[kCGImagePropertyExifDateTimeOriginal as String] = formattedCaptureDate
        exifDict[kCGImagePropertyExifLensModel as String] = lensInfo
        exifDict[kCGImagePropertyExifExposureTime as String] = exposureTime
        exifDict[kCGImagePropertyExifFNumber as String] = fNumber
        exifDict[kCGImagePropertyExifFocalLenIn35mmFilm as String] = focalLenIn35mmFilm
        exifDict[kCGImagePropertyExifFocalLength as String] = focalLength
        exifDict[kCGImagePropertyExifISOSpeedRatings as String] = ISOSPEEDRatings
        newProps[kCGImagePropertyExifDictionary as String] = exifDict
        
        var tiffDict = (newProps[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
        tiffDict[kCGImagePropertyTIFFModel as String] = cameraInfo
        newProps[kCGImagePropertyTIFFDictionary as String] = tiffDict
        
        var gpsDict = (newProps[kCGImagePropertyGPSDictionary as String] as? [String: Any]) ?? [:]
        gpsDict[kCGImagePropertyGPSLatitude as String] = Double(latitude) ?? 0.0
        gpsDict[kCGImagePropertyGPSLongitude as String] = Double(longitude) ?? 0.0
        gpsDict[kCGImagePropertyGPSAltitude as String] = altitude
        newProps[kCGImagePropertyGPSDictionary as String] = gpsDict
        
        CGImageDestinationAddImageFromSource(destination, source, 0, newProps as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            let title = URL(fileURLWithPath: imageName).deletingPathExtension().lastPathComponent
            imageName = fileName
            saveMessage = "\(title) " + NSLocalizedString("image_saved_successfully", comment: "")
            
            if let savedImageData = try? Data(contentsOf: fileURL) {
                printEXIFInfo(from: savedImageData)
            } else {
                print("Failed to read saved image data")
            }
            
            let thumbnail100 = generateThumbnail(for: inputImage, size: CGSize(width: 100, height: 100))
            let thumbnail350 = generateThumbnail(for: inputImage, size: CGSize(width: 350, height: 350))
            
            let thumbnail100Name = "\(uuid)_thumb100.jpg"
            let thumbnail350Name = "\(uuid)_thumb350.jpg"
            let thumbnail100Path = portfolioDirectory.appendingPathComponent(thumbnail100Name)
            let thumbnail350Path = portfolioDirectory.appendingPathComponent(thumbnail350Name)
            
            do {
                try thumbnail100?.jpegData(compressionQuality: 0.8)?.write(to: thumbnail100Path)
                try thumbnail350?.jpegData(compressionQuality: 0.8)?.write(to: thumbnail350Path)
            } catch {
                saveMessage = "Failed to save thumbnails: \(error)"
                showingSaveMessage = true
                return
            }
            
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
        } else {
            saveMessage = "Failed to save image"
        }
        
        UserDefaults.standard.set(false, forKey: "isFirstLaunch")
        showingSaveMessage = true
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

extension AddImageView {
    static func handleIncomingURL(_ url: URL) -> AddImageView {
        var view = AddImageView()
        view.receivedImageURL = url
        view.loadImageFromURL(url)
        return view
    }

    mutating func loadImageFromURL(_ url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let imageData = try? Data(contentsOf: url),
               let uiImage = UIImage(data: imageData) {
                self.inputImage = uiImage
                self.imageName = url.lastPathComponent
                loadImage()
                extractEXIFData(from: imageData)
            } else {
                saveMessage = "Failed to load image from URL"
                showingSaveMessage = true
            }
        } else {
            saveMessage = "Failed to access the image file"
            showingSaveMessage = true
        }
    }

    private mutating func extractEXIFData(from imageData: Data) {
        if let source = CGImageSourceCreateWithData(imageData as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            if let exif = properties["{Exif}"] as? [String: Any] {
                captureDate = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String ?? ""
                exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? Double ?? 0.0
                fNumber = exif[kCGImagePropertyExifFNumber as String] as? Double ?? 0.0
                focalLenIn35mmFilm = exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Double ?? 0.0
                focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double ?? 0.0
                ISOSPEEDRatings = exif[kCGImagePropertyExifISOSpeedRatings as String] as? Int ?? 0
            }
            if let tiff = properties["{TIFF}"] as? [String: Any] {
                cameraInfo = tiff[kCGImagePropertyTIFFModel as String] as? String ?? ""
                lensInfo = tiff[kCGImagePropertyTIFFMake as String] as? String ?? ""
            }
            if let gps = properties["{GPS}"] as? [String: Any] {
                latitude = String(gps[kCGImagePropertyGPSLatitude as String] as? Double ?? 0.0)
                longitude = String(gps[kCGImagePropertyGPSLongitude as String] as? Double ?? 0.0)
                altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double ?? 0.0
            }
        }
    }
}
