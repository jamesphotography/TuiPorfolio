import SwiftUI

struct CameraDetailView: View {
    let cameraModel: String
    @State private var photos: [Photo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPhotoIndex: Int?
    @State private var sortOrder: SortOrder = .descending

    enum SortOrder {
        case ascending, descending
    }

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
        HeadBarView(title: cameraModel)
            .padding(.top, geometry.safeAreaInsets.top)
    }

    private func mainContentView(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack{
                    statusView
                    Spacer()
                    sortingButton
                }
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
                Text("No photos found for this camera model")
                    .padding()
            } else {
                Text("Found \(photos.count) photos")
                    .font(.headline)
                    .padding(.leading, 16)
                    .padding(.top, 8)
            }
        }
    }

    private var sortingButton: some View {
        Button(action: {
            sortOrder = sortOrder == .ascending ? .descending : .ascending
            sortPhotos()
        }) {
            HStack {
                Text("Sort by time")
                Image(systemName: sortOrder == .ascending ? "arrow.up.square" : "arrow.down.square")
            }
            .foregroundColor(Color("TUIBLUE"))
            .font(.subheadline)
        }
        .padding(.horizontal)
    }

    private func photoGridView(geometry: GeometryProxy) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                NavigationLink(destination: DetailView(photos: photos, initialIndex: index) { returnedIndex in
                    self.selectedPhotoIndex = returnedIndex
                }) {
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
            let loadedPhotos = SQLiteManager.shared.getPhotosByCamera(cameraModel)
            
            DispatchQueue.main.async {
                self.photos = loadedPhotos
                self.sortPhotos()
                self.isLoading = false
                if loadedPhotos.isEmpty {
                    self.errorMessage = "No photos found for this camera model"
                }
            }
        }
    }

    private func sortPhotos() {
        photos.sort { (photo1, photo2) in
            let date1 = dateFromString(photo1.dateTimeOriginal)
            let date2 = dateFromString(photo2.dateTimeOriginal)
            return sortOrder == .ascending ? date1 < date2 : date1 > date2
        }
    }

    private func dateFromString(_ dateString: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: dateString) ?? Date.distantPast
    }

    private func loadImage(from path: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(path).path
        
        return fileManager.fileExists(atPath: fullPath) ? UIImage(contentsOfFile: fullPath) : nil
    }
}
