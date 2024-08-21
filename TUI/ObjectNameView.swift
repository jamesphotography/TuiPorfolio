import SwiftUI

struct ObjectNameView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var photos: [Photo] = []
    @State private var showAlert = false
    @State private var loadMore = false
    let objectName: String

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // HeadBarView
                HeadBarView(title: objectName)
                    .padding(.top, geometry.safeAreaInsets.top)

                // Main content area
                ScrollView {
                    VStack(spacing: 8) {
                        if photos.isEmpty {
                            Text("No matching works found")
                                .padding()
                        } else {
                            Text("Found \(photos.count) photos")
                                .font(.headline)
                                .padding(.leading, 16)
                                .padding(.top, 8)
                            
                            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                                NavigationLink(destination: DetailView(photos: photos, initialIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0, onDismiss: { _ in })) {
                                    HStack {
                                        photoThumbnail(for: photo)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(photo.title)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(photo.dateTimeOriginal)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }

                            if photos.count > 9 && !loadMore {
                                Button("Load More") {
                                    loadMorePhotos()
                                }
                                .padding()
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .background(Color("BGColor"))

                // Bottom navigation bar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadPhotos)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text("Unable to load photo(s)"), dismissButton: .default(Text("OK")))
        }
    }

    private func photoThumbnail(for photo: Photo) -> some View {
        Group {
            if let uiImage = loadImage(from: photo.thumbnailPath100) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(5)
            } else {
                Text("Image not found")
                    .foregroundColor(.red)
                    .frame(width: 60, height: 60)
            }
        }
    }

    private func loadPhotos() {
        let loadedPhotos = SQLiteManager.shared.getPhotosByObjectName(objectName)
        if loadedPhotos.isEmpty {
            showAlert = true
        } else {
            photos = loadedPhotos
        }
    }

    private func loadMorePhotos() {
        loadMore = true
        // Load more logic
        // For example, you can load more photos from the database and add them to the photos array
        loadMore = false
    }

    private func loadImage(from path: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(path).path
        
        return fileManager.fileExists(atPath: fullPath) ? UIImage(contentsOfFile: fullPath) : nil
    }
}

struct ObjectNameView_Previews: PreviewProvider {
    static var previews: some View {
        ObjectNameView(objectName: "Sample Object Name")
    }
}
