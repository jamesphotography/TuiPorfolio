import SwiftUI

struct SameDayView: View {
    var date: String
    var currentPhotoID: String
    @State private var photos: [Photo] = []
    @State private var selectedPhotoIndex: Int?
    
    var body: some View {
        VStack(alignment: .leading) {
            if photos.count > 1 {
                HStack {
                    Spacer()
                    Text("Photos taken on the same day")
                        .font(.caption2)
                    Spacer()
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(photos.prefix(9).filter { $0.id != currentPhotoID }, id: \.id) { photo in
                        if let uiImage = loadImage(from: photo.thumbnailPath100) {
                            NavigationLink(destination: DetailView(photos: photos, initialIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0) { index in
                                self.selectedPhotoIndex = index
                            }) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .clipped()
                                    .cornerRadius(3)
                                    .shadow(radius: 3)
                            }
                        }
                    }
                }
                .padding()
                if photos.count > 9 {
                    NavigationLink(destination: MorePhotosView(date: date)) {
                        Text("More Photos")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding()
                    }
                }
            }
        }
        .onAppear {
            loadPhotos()
        }
    }
    
    func loadPhotos() {
        let allPhotos = SQLiteManager.shared.getAllPhotos()
        photos = allPhotos.filter { $0.dateTimeOriginal.starts(with: date) }
    }
    
    func loadImage(from relativePath: String) -> UIImage? {
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fullPath = documentsDirectory.appendingPathComponent(relativePath).path
            if fileManager.fileExists(atPath: fullPath) {
                return UIImage(contentsOfFile: fullPath)
            }
        }
        return nil
    }
}
