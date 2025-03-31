import SwiftUI

struct PhotoListView: View {
    var photos: [Photo]
    var loadMoreAction: (() -> Void)?
    var canLoadMore: Bool = false
    @AppStorage("omitCameraBrand") private var omitCameraBrand = false
    
    var body: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(photos, id: \.id) { photo in
                    NavigationLink(destination: DetailView(photo: photo)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(photo.objectName.isEmpty ? photo.title : photo.objectName)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                Text("\(formatDate(dateTimeOriginal: photo.dateTimeOriginal)) - \(photo.locality), \(photo.area), \(photo.country)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                
                                if !photo.caption.isEmpty {
                                    Text(photo.caption)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                
                                Text(formatCameraAndLens(camera: photo.model, lens: photo.lensModel))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.vertical, 4)
                            
                            Spacer()
                            
                            PhotoThumbnail(photo: photo)
                        }
                    }
                }
                
                if canLoadMore, let loadMoreAction = loadMoreAction {
                    HStack {
                        Text("1 - \(photos.count) photos")
                            .font(.caption2)
                            .padding(.leading)
                        Spacer()
                        
                        Button(action: loadMoreAction) {
                            Text("Load More")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color("TUIBLUE"))
                                .cornerRadius(5)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            
        }
        .padding(.top, 8) // 适当调整顶部间距
    }
    
    private func formatDate(dateTimeOriginal: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: dateTimeOriginal) {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.string(from: date)
        }
        return dateTimeOriginal
    }
    
    private func formatCameraAndLens(camera: String, lens: String) -> String {
        let formattedCamera = omitCameraBrand ? removeBrandName(from: camera) : camera
        let formattedLens = omitCameraBrand ? removeBrandName(from: lens) : lens
        return "\(formattedCamera), \(formattedLens)"
    }
    
    private func removeBrandName(from model: String) -> String {
        let brandNames = ["Nikon", "Canon", "Sony", "Fujifilm", "Panasonic", "Olympus", "Leica", "Hasselblad", "Pentax", "Sigma", "Tamron", "Zeiss", "Nikkor"]
        var result = model
        
        for brand in brandNames {
            if result.lowercased().contains(brand.lowercased()) {
                result = result.replacingOccurrences(of: brand, with: "", options: [.caseInsensitive, .anchored])
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return result
    }
    
    private func formatCoordinates(latitude: Double, longitude: Double) -> String {
        let latString = String(format: "%.2f", abs(latitude))
        let longString = String(format: "%.2f", abs(longitude))
        let latDirection = latitude >= 0 ? "N" : "S"
        let longDirection = longitude >= 0 ? "E" : "W"
        return "\(longString)° \(longDirection) \(latString)° \(latDirection)"
    }
    
    private func loadImage(from path: String) -> UIImage? {
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
}

struct PhotoThumbnail: View {
    let photo: Photo
    
    var body: some View {
        Group {
            if let uiImage = loadImage(from: photo.thumbnailPath350) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(5)
            } else {
                Color.gray
                    .frame(width: 100, height: 100)
                    .cornerRadius(5)
            }
        }
    }
    
    private func loadImage(from path: String) -> UIImage? {
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
}
