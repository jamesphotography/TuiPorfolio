import SwiftUI
import MapKit

enum NavigationDestination: Hashable {
    case locality(String)
    case area(String)      // 新增的省份导航类型
    case country(String)
    case date(Date)
    case objectName(String)
    case detail(Int)
}

struct BlockView: View {
    let photo: Photo
    var index: Int
    @State private var description: String
    @State private var date: Date?
    @State private var rating: Double
    @State private var country: String
    @State private var area: String
    @State private var locality: String
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var objectName: String
    @State private var thumbnailPath350: String
    @State private var imageExists: Bool = false
    
    var onNavigate: (NavigationDestination) -> Void
    
    init(photo: Photo, index: Int, onNavigate: @escaping (NavigationDestination) -> Void) {
        self.photo = photo
        self.index = index
        self._rating = State(initialValue: Double(photo.starRating))
        self._country = State(initialValue: photo.country)
        self._area = State(initialValue: photo.area)
        self._locality = State(initialValue: photo.locality)
        self._objectName = State(initialValue: photo.objectName)
        self._thumbnailPath350 = State(initialValue: photo.thumbnailPath350)
        self._description = State(initialValue: photo.objectName.isEmpty ? photo.title : photo.objectName)
        self.onNavigate = onNavigate
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self._date = State(initialValue: dateFormatter.date(from: photo.dateTimeOriginal))
        
        self._latitude = State(initialValue: photo.latitude)
        self._longitude = State(initialValue: photo.longitude)
    }
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 350, height: 350)
                
                if imageExists, let uiImage = loadImage(named: thumbnailPath350) {
                    let aspectRatio = uiImage.size.height / uiImage.size.width
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 350)
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .clipped()
                        .cornerRadius(5)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Image not available")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .shadow(radius: 5)
            .padding(.all, 5)
            .frame(maxWidth: .infinity)
            
            HStack {
                if !objectName.isEmpty {
                    Button(action: { onNavigate(.objectName(objectName)) }) {
                        Text(truncatedString(description, limit: 24))
                            .font(.subheadline)
                    }
                } else {
                    Text(truncatedString(description, limit: 24))
                        .font(.subheadline)
                }
                Spacer()


            }
            HStack(spacing: 4) {
                HStack {
                    if let date = date {
                        Button(action: { onNavigate(.date(date)) }) {
                            Text(formattedDate(date))
                                .font(.caption)
                        }
                    } else {
                        Text("Unknown Date")
                            .font(.caption)
                    }
                }
                Spacer()
                Button(action: { onNavigate(.locality(locality)) }) {
                    Text(truncatedString(locality, limit: 16))
                        .font(.caption)
                }

                Button(action: { onNavigate(.country(country)) }) {
                    Text(area)
                        .font(.caption)
                    Text(", ")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(country)
                        .font(.caption)
                }
            }
            .foregroundColor(.blue)
        }
        .onAppear {
            checkImageExistence()
        }
        .frame(maxWidth: 350)
    }
    
    func checkImageExistence() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(thumbnailPath350).path
        imageExists = fileManager.fileExists(atPath: fullPath)
    }
    
    func loadImage(named imageName: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(imageName).path
        if fileManager.fileExists(atPath: fullPath) {
            return UIImage(contentsOfFile: fullPath)
        }
        return nil
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy-MM-dd"
        return formatter.string(from: date)
    }
    
    func truncatedString(_ text: String, limit: Int) -> String {
        var truncated = ""
        var length = 0
        for char in text {
            if length >= limit {
                truncated += "."
                break
            }
            if char.isASCII {
                length += 1
            } else {
                length += 2
            }
            truncated.append(char)
        }
        return truncated
    }
    
    func getLocation() -> CLLocationCoordinate2D? {
        if let latitude = latitude, let longitude = longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return nil
    }
}
