import SwiftUI
import MapKit

enum ViewMode {
    case grid
    case list
}

struct LocalityPhotoListView: View {
    let locality: String
    @State private var photos: [Photo] = []
    @State private var displayedPhotos: [Photo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var birdSpeciesCount: Int = 0
    @State private var totalPhotoCount: Int = 0
    @State private var currentPage = 0
    @State private var viewMode: ViewMode = .grid
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    private let itemsPerPage = 30
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: locality)
                    .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 10) {
                        // 地图视图
                        if let firstPhoto = photos.first {
                            Map(position: .constant(.region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(
                                    latitude: firstPhoto.latitude,
                                    longitude: firstPhoto.longitude
                                ),
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )))) {
                                Marker(locality, coordinate: CLLocationCoordinate2D(
                                    latitude: firstPhoto.latitude,
                                    longitude: firstPhoto.longitude
                                ))
                            }
                            .frame(height: 200)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        // 统计信息和视图切换按钮
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(totalPhotoCount) Photos")
                                    .font(.headline)
                                    .foregroundColor(Color("TUIBLUE"))
                                
                                if enableBirdWatching {
                                    Text("\(birdSpeciesCount) Bird Species")
                                        .font(.headline)
                                        .foregroundColor(Color("TUIBLUE"))
                                }
                            }
                            
                            Spacer()
                            
                            // 视图切换按钮
                            Button(action: {
                                withAnimation {
                                    viewMode = viewMode == .grid ? .list : .grid
                                }
                            }) {
                                Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.3x3")
                                    .foregroundColor(Color("TUIBLUE"))
                                    .font(.system(size: 20))
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(radius: 1)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        
                        // 照片显示区域
                        if viewMode == .grid {
                            gridView(geometry: geometry)
                        } else {
                            listView
                        }
                        
                        // 加载更多按钮
                        if !photos.isEmpty && displayedPhotos.count < photos.count {
                            Button(action: loadMorePhotos) {
                                Text("Load more ...")
                                    .foregroundColor(.white)
                                    .font(.caption)
                                    .padding(8)
                                    .frame(maxWidth: UIScreen.main.bounds.width / 2)
                                    .background(Color.black)
                                    .cornerRadius(15)
                            }
                            .padding(.vertical)
                        }
                        
                        if photos.isEmpty && !isLoading {
                            Text("No photos in this area")
                                .foregroundColor(.gray)
                                .padding()
                        }
                        
                        if isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                }
                .background(Color("BGColor"))
                
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear {
            loadPhotos()
        }
    }
    
    private var listView: some View {
        LazyVStack(spacing: 8) {
            ForEach(displayedPhotos) { photo in
                NavigationLink(destination: DetailView(photo: photo)) {
                    HStack(spacing: 12) {
                        // 缩略图
                        PhotoThumbnailView(photo: photo, size: 60)
                            .cornerRadius(6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if enableBirdWatching && !photo.objectName.isEmpty {
                                Text(photo.objectName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            } else {
                                Text(photo.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            // 时间和地点
                            Text(formatDateTime(photo.dateTimeOriginal))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func gridView(geometry: GeometryProxy) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(displayedPhotos) { photo in
                NavigationLink(destination: DetailView(photo: photo)) {
                    PhotoThumbnailView(photo: photo, size: (geometry.size.width - 40) / 3)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func formatDateTime(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yy-MM-dd HH:mm"
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
    
    // [其他现有的函数保持不变]
    private func loadPhotos() {
        isLoading = true
        
        let localityPhotos = SQLiteManager.shared.getAllPhotos().filter { $0.locality == locality }
        photos = localityPhotos.sorted { $0.dateTimeOriginal > $1.dateTimeOriginal }
        totalPhotoCount = localityPhotos.count
        
        if enableBirdWatching {
            let uniqueBirdSpecies = Set(localityPhotos.compactMap { photo -> String? in
                guard !photo.objectName.isEmpty else { return nil }
                return isBirdSpecies(photo.objectName) ? photo.objectName : nil
            })
            birdSpeciesCount = uniqueBirdSpecies.count
        }
        
        loadMorePhotos()
        isLoading = false
        
        if let firstPhoto = photos.first {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: firstPhoto.latitude,
                    longitude: firstPhoto.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
    
    private func loadMorePhotos() {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, photos.count)
        
        if startIndex < endIndex {
            displayedPhotos.append(contentsOf: photos[startIndex..<endIndex])
            currentPage += 1
        }
    }
    
    private func isBirdSpecies(_ name: String) -> Bool {
        guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let birdList = try? JSONDecoder().decode([[String]].self, from: data) else {
            return false
        }
        
        return birdList.contains { birdNames in
            birdNames.contains(name)
        }
    }
}
