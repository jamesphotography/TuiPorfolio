import SwiftUI
import MapKit

struct NationalPhotoListView: View {
    var country: String
    var locality: String?
    @State private var photos: [Photo] = []
    @State private var currentPage = 1
    @State private var executionTime: TimeInterval = 0
    private let itemsPerPage = 9
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                headbar(geometry: geometry)
                mainContent(geometry: geometry)
                executionTimeView
                bottombar(geometry: geometry)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
    }
    
    private func headbar(geometry: GeometryProxy) -> some View {
        HeadBarView(title: locality != nil ? "\(country), \(locality!)" : country)
            .padding(.top, geometry.safeAreaInsets.top)
    }
    
    private func mainContent(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 20) {
                ForEach(Array(photos.prefix(currentPage * itemsPerPage).enumerated()), id: \.element.id) { index, photo in
                    photoLink(photo: photo)
                }
            }
            
            loadMoreButton
        }
        .padding(.horizontal, 5)
        .onAppear(perform: loadPhotos)
    }
    
    private func photoLink(photo: Photo) -> some View {
        NavigationLink(destination:  DetailView(photo: photo)){
            PhotoThumbnailView(photo: photo, size: (UIScreen.main.bounds.width / 3) - 15)
        }
    }
    
    private var loadMoreButton: some View {
        Group {
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
    }
    
    private var executionTimeView: some View {
        Group {
            if !photos.isEmpty {
                Text("Execution Time: \(String(format: "%.3f", executionTime))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
            }
        }
    }
    
    private func bottombar(geometry: GeometryProxy) -> some View {
        BottomBarView()
            .padding(.bottom, geometry.safeAreaInsets.bottom)
    }

    private func loadPhotos() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        photos = SQLiteManager.shared.getAllPhotos()
            .filter { $0.country == country && (locality == nil || $0.locality == locality) }
            .sorted { $0.dateTimeOriginal > $1.dateTimeOriginal }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        executionTime = endTime - startTime
    }
}

struct NationalPhotoListView_Previews: PreviewProvider {
    static var previews: some View {
        NationalPhotoListView(country: "Australia")
    }
}
