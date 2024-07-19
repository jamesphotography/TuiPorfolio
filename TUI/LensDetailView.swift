import SwiftUI

struct LensDetailView: View {
    let lensModel: String
    @State private var photos: [Photo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headerView(geometry: geometry)
                mainContentView(geometry: geometry)
                footerView(geometry: geometry)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadPhotos)
    }

    private func headerView(geometry: GeometryProxy) -> some View {
        HeadBarView(title: lensModel)
            .padding(.top, geometry.safeAreaInsets.top)
    }

    private func mainContentView(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                statusView
                photoGridView(geometry: geometry)
            }
            .padding(.top, 8)
        }
        .background(Color("BGColor"))
    }

    private var statusView: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
                    .padding()
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else if photos.isEmpty {
                Text("No photos found for this lens model")
                    .padding()
            } else {
                Text("Found \(photos.count) photos")
                    .font(.caption2)
                    .padding(.leading, 16)
                    .padding(.top, 8)
            }
        }
    }

    private func photoGridView(geometry: GeometryProxy) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                NavigationLink(destination: DetailView(photos: photos, initialIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0, onDismiss: { _ in })) {
                    photoThumbnail(for: photo)
                        .frame(width: (geometry.size.width - 40) / 3, height: (geometry.size.width - 40) / 3)
                        .clipped()
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
    }

    private func footerView(geometry: GeometryProxy) -> some View {
        BottomBarView()
            .padding(.bottom, geometry.safeAreaInsets.bottom)
    }

    private func photoThumbnail(for photo: Photo) -> some View {
        Group {
            if let uiImage = loadImage(from: photo.thumbnailPath100) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Text("Image not found")
                    .foregroundColor(.red)
            }
        }
    }

    private func loadPhotos() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .background).async {
            let loadedPhotos = SQLiteManager.shared.getPhotosByLens(lensModel)
            
            DispatchQueue.main.async {
                self.photos = loadedPhotos
                self.isLoading = false
                if loadedPhotos.isEmpty {
                    self.errorMessage = "No photos found for this lens model"
                }
            }
        }
    }

    private func loadImage(from path: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(path).path
        
        return fileManager.fileExists(atPath: fullPath) ? UIImage(contentsOfFile: fullPath) : nil
    }
}

struct LensDetailView_Previews: PreviewProvider {
    static var previews: some View {
        LensDetailView(lensModel: "Sample Lens")
    }
}
