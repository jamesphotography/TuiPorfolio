import SwiftUI
import MapKit

struct NationalPhotoListView: View {
    var country: String
    var locality: String?
    @State private var photos: [Photo] = []
    @State private var currentPage = 1
    private let itemsPerPage = 9
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(title: locality != nil ? "\(country), \(locality!)" : country)
                    .padding(.top, geometry.safeAreaInsets.top)

                // Main
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 20) {
                        ForEach(Array(photos.prefix(currentPage * itemsPerPage).enumerated()), id: \.element.id) { index, photo in
                            NavigationLink(destination: DetailView(photos: photos, initialIndex: photos.firstIndex(where: { $0.id == photo.id }) ?? 0, onDismiss: { _ in })) {
                                PhotoThumbnailView(photo: photo, size: (UIScreen.main.bounds.width / 3) - 15)
                            }
                        }
                    }
                    
                    if photos.count > currentPage * itemsPerPage {
                        Button(action: {
                            currentPage += 1
                        }) {
                            Text("Load more ...")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .padding(8)
                                .frame(maxWidth: UIScreen.main.bounds.width / 2)
                                .background(Color.black)
                                .cornerRadius(15)
                        }
                        .padding(.top)
                    }
                }
                .padding(.horizontal, 5)
                .onAppear(perform: loadPhotos)

                // Bottombar
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
    }

    private func loadPhotos() {
        photos = SQLiteManager.shared.getAllPhotos()
            .filter { $0.country == country && (locality == nil || $0.locality == locality) }
            .sorted { $0.dateTimeOriginal > $1.dateTimeOriginal }
    }

    private func loadImage(named imageName: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(imageName).path
        if fileManager.fileExists(atPath: fullPath) {
            return UIImage(contentsOfFile: fullPath)
        }
        return nil
    }
}

struct NationalPhotoListView_Previews: PreviewProvider {
    static var previews: some View {
        NationalPhotoListView(country: "Australia")
    }
}
