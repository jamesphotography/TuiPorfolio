import SwiftUI

struct PhotoImageView: View {
    let photo: Photo
    let imagePath: String
    let geometry: GeometryProxy
    @Binding var showZoomInView: Bool
    @Binding var showCopiedAlert: Bool
    @Binding var navigationDestination: String?
    @Binding var selectedDate: Date?
    @Binding var country: String
    @Binding var locality: String
    
    var body: some View {
        VStack {
            if photo.starRating > 0 {
                StarRatingView(rating: Double(photo.starRating))
                    .padding(.top, 5)
            }
            
            if let uiImage = loadImage(from: imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width)
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 10)
                    .onTapGesture {
                        showZoomInView.toggle()
                    }
            } else {
                Text("Image could not be loaded")
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading) {
                // Photo Info Section
                HStack {
                    Image(systemName: "camera.badge.ellipsis")
                        .foregroundColor(.orange)
                        .onLongPressGesture {
                            copyExifToClipboard(photo: photo)
                            showCopiedAlert = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopiedAlert = false
                            }
                        }
                    Spacer()
                    VStack {
                        Text(photo.model)
                        Text(photo.lensModel.isEmpty ? "" : " \(photo.lensModel)")
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.2.square.on.square")
                        .foregroundColor(Color("TUIBLUE"))
                        .onTapGesture {
                            navigationDestination = "editor"
                        }
                }
                .padding(2)
                
                HStack {
                    Spacer()
                    if photo.focalLenIn35mmFilm != photo.focalLength {
                        Text("\(Int(photo.focalLenIn35mmFilm))mm")
                        Text("\(Int(photo.focalLength))mm")
                    } else {
                        Text("\(Int(photo.focalLength))mm")
                    }
                    Text(" f/\(String(format: "%.1f", photo.fNumber))")
                    Text(" \(formatExposureTime(photo.exposureTime))s")
                    Text(" ISO\(photo.ISOSPEEDRatings)")
                    Spacer()
                }
                .padding(2)
                
                // Location and Date Section
                HStack {
                    Spacer()
                    Text(formatDateTimeOriginal(photo.dateTimeOriginal))
                        .underline()
                        .padding(2)
                        .onTapGesture {
                            if let date = photo.dateTimeOriginal.split(separator: " ").first {
                                let calendarDate = String(date)
                                print(calendarDate)
                                if let selectedDate = dateFromString(calendarDate) {
                                    self.selectedDate = selectedDate
                                    navigationDestination = "calendar"
                                }
                            }
                        }
                    Spacer()
                }
                HStack {
                    Spacer()
                    if !photo.country.isEmpty && !photo.locality.isEmpty {
                        Text(photo.country)
                            .underline()
                            .padding(2)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                print(photo.country)
                                navigationDestination = "national"
                            }
                        
                        Text(photo.locality)
                            .underline()
                            .padding(2)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                print(photo.locality)
                                navigationDestination = "locality"
                            }
                        
                        Text(formatCoordinates(latitude: photo.latitude, longitude: photo.longitude))
                            .underline()
                            .padding(2)
                            .foregroundColor(.blue)
                            .onTapGesture {
                                print("Navigating to MapView with GPS coordinates")
                                navigationDestination = "map"
                            }
                    }
                    Spacer()
                }
                
                if !photo.caption.isEmpty {
                    Text(photo.caption)
                        .padding(2)
                }
            }
            .font(.custom("SF Pro", size: 14).weight(.thin))
            .frame(maxWidth: geometry.size.width)
            .padding(10)
            .background(Color.white.opacity(0.8))
            .cornerRadius(5)
            .shadow(radius: 3)
            
            // 显示同一天拍摄的照片
            if let dateTimeOriginal = photo.dateTimeOriginal.split(separator: " ").first {
                SameDayView(date: String(dateTimeOriginal), currentPhotoID: photo.id)
                    .padding(.top)
            }
        }
    }
    
    // 在这里添加所有必要的辅助函数，如 loadImage, formatExposureTime, copyExifToClipboard, formatDateTimeOriginal, formatCoordinates, dateFromString 等
    // 加载图片文件
    func loadImage(from path: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(path).path
        
        if fileManager.fileExists(atPath: fullPath) {
            return UIImage(contentsOfFile: fullPath)
        } else {
            print("File does not exist at path: \(fullPath)")
            return nil
        }
    }
    
    func formatCoordinates(latitude: Double, longitude: Double) -> String {
        let latitudeString = String(format: "%.2f", abs(latitude))
        let longitudeString = String(format: "%.2f", abs(longitude))
        let latitudeDirection = latitude >= 0 ? "N" : "S"
        let longitudeDirection = longitude >= 0 ? "E" : "W"
        return "\(latitudeString)° \(latitudeDirection), \(longitudeString)° \(longitudeDirection)"
    }
    
    func copyExifToClipboard(photo: Photo) {
        var exifData = """
        Model: \(photo.model)
        Lens Model: \(photo.lensModel)
        Focal Length: \(photo.focalLength)mm
        F-Number: f/\(photo.fNumber)
        Exposure Time: \(formatExposureTime(photo.exposureTime))s
        ISO Speed Ratings: \(photo.ISOSPEEDRatings)
        Latitude: \(photo.latitude)
        Longitude: \(photo.longitude)
        DateTime Original: \(photo.dateTimeOriginal)
        """
        
        if !photo.objectName.isEmpty {
            exifData += "\nObject Name: \(photo.objectName)"
        }
        
        if !photo.caption.isEmpty {
            exifData += "\nCaption: \(photo.caption)"
        }
        
        UIPasteboard.general.string = exifData
    }
    
    // 格式化曝光时间
    func formatExposureTime(_ exposureTime: Double) -> String {
        if exposureTime >= 1 {
            return String(format: "%.1f", exposureTime)
        } else if exposureTime > 0 {
            let denominator = Int(round(1 / exposureTime))
            return "1/\(denominator)"
        } else {
            return "Invalid Exposure Time"
        }
    }
    
    // 格式化日期时间
    func formatDateTimeOriginal(_ dateTimeOriginal: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let originalDate = dateFormatter.date(from: dateTimeOriginal) {
            return dateFormatter.string(from: originalDate)
        } else {
            return dateTimeOriginal
        }
    }
    
    func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
}
