import SwiftUI

struct ContentView: View {
    @State private var images: [(path: String, date: Date)] = []
    @State private var displayedImages: [(path: String, date: Date)] = []
    @AppStorage("userName") private var userName: String = "Tui"
    @AppStorage("sortByShootingTime") private var sortByShootingTime = true
    @AppStorage("useWaterfallLayout") private var useWaterfallLayout = false
    @AppStorage("useSingleColumnLayout") private var useSingleColumnLayout = false
    @State private var needsReload: Bool = true
    @State private var page: Int = 0
    @State private var isRefreshing: Bool = false
    @State private var lastRefreshTime: Date = Date.distantPast
    @State private var navigationPath = NavigationPath()
    @Environment(\.presentationMode) var presentationMode
    private let itemsPerPage: Int = 100
    @State private var selectedPhotoIndex: Int?
    @State private var contentHeight: CGFloat = 0
    @State private var previousPathCount: Int = 0
    @State private var screenSize: CGSize = .zero
    @State private var safeAreaInsets: EdgeInsets = .init()
    @State private var refreshTrigger = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    headerView
                    mainContentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    bottomBarView(geometry: geometry)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("BGColor").edgesIgnoringSafeArea(.all))
                .ignoresSafeArea()
                .navigationTitle("")
                .navigationBarHidden(true)
                .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                    needsReload = true
                }
                .onAppear {
                    performRefreshIfNeeded()
                    screenSize = geometry.size
                    safeAreaInsets = geometry.safeAreaInsets
                }
                .onChange(of: navigationPath) { _, newPath in
                    previousPathCount = newPath.count
                }
                .onChange(of: geometry.size) { _, newSize in
                    screenSize = newSize
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .locality(let locality):
                    LocalityPhotoListView(locality: locality)
                case .area(let area):
                    StatePhotoListView(area: area)
                case .country(let country):
                    NationalPhotoListView(country: country)
                case .date(let date):
                    CalendarView(date: date)
                case .objectName(let name):
                    ObjectNameView(objectName: name)
                case .detail(let index):
                    if index < displayedImages.count {
                        let photo = getPhoto(for: displayedImages[index].path)
                        DetailView(photo: photo)
                    } else {
                        Text("Photo not found")
                    }
                }
            }
        }
    }

    var headerView: some View {
        HeadBarView(title: "\(userName)\(NSLocalizedString("'s Portfolio", comment: ""))")
            .padding(.top, topSafeAreaInset)
    }

    var mainContentView: some View {
        Group {
            if !useSingleColumnLayout {
                WaterfallView(
                    photos: displayedImages.map { getPhoto(for: $0.path) },
                    onPhotoTapped: { photo in
                        if let index = displayedImages.firstIndex(where: { $0.path == photo.path }) {
                            self.selectedPhotoIndex = index
                            navigationPath.append(NavigationDestination.detail(index))
                        }
                    },
                    onNavigate: { destination in
                        navigationPath.append(destination)
                    },
                    loadMore: loadMoreImages,
                    hasMoreImages: displayedImages.count < images.count,
                    selectedIndex: selectedPhotoIndex
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(Array(displayedImages.enumerated()), id: \.element.path) { index, image in
                                let photo = getPhoto(for: image.path)
                                BlockView(photo: photo, index: index) { destination in
                                    navigationPath.append(destination)
                                }
                                .onTapGesture {
                                    self.selectedPhotoIndex = index
                                    navigationPath.append(NavigationDestination.detail(index))
                                }
                                .id(index)
                            }
                            loadMoreButton
                        }
                        .padding()
                    }
                    .onChange(of: selectedPhotoIndex) { oldValue, newValue in
                        if let newIndex = newValue {
                            withAnimation {
                                proxy.scrollTo(newIndex, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .id(refreshTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .settingsChanged)) { _ in
            needsReload = true
            loadImages()
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoDeleted)) { _ in
            needsReload = true
            loadImages()
        }
        .refreshable {
            await forceRefresh()
        }
        .background(Color("BGColor"))
    }

    var loadMoreButton: some View {
        Group {
            if displayedImages.count < images.count {
                Button(action: loadMoreImages) {
                    Text("Load more ...")
                        .foregroundColor(.white)
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: UIScreen.main.bounds.width / 2)
                        .background(Color.black)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 20)
            } else {
                Text("No More Images")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                    .padding(8)
                    .frame(maxWidth: UIScreen.main.bounds.width / 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                    .padding(.horizontal, 20)
            }
        }
    }

    func bottomBarView(geometry: GeometryProxy) -> some View {
        BottomBarView()
            .padding(.bottom, geometry.safeAreaInsets.bottom)
    }

    var topSafeAreaInset: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets.top ?? 0
    }

    func forceRefresh() async {
        isRefreshing = true
        SQLiteManager.shared.invalidateCache()
        loadImages()
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        isRefreshing = false
        lastRefreshTime = Date()
    }
    
    func loadImages() {
        SQLiteManager.shared.invalidateCache()
        let photos = SQLiteManager.shared.getAllPhotos(sortByShootingTime: sortByShootingTime)
        print("Loaded \(photos.count) photos from database")
        
        images = []
        displayedImages = []
        
        images = photos.map { photo in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let date = sortByShootingTime ?
                dateFormatter.date(from: photo.dateTimeOriginal) :
                dateFormatter.date(from: photo.addTimestamp)
            return (path: photo.path, date: date ?? Date())
        }

        page = 0
        loadMoreImages()
        refreshTrigger.toggle()
    }
    
    func loadMoreImages() {
        let startIndex = page * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, images.count)
        if startIndex < endIndex {
            let newImages = images[startIndex..<endIndex]
            displayedImages.append(contentsOf: newImages)
            page += 1
        }
    }
    
    func performRefreshIfNeeded() {
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastRefreshTime) > 5 {
            Task {
                await forceRefresh()
            }
        }
    }
    
    func getPhoto(for path: String) -> Photo {
        return SQLiteManager.shared.getPhoto(for: path) ?? Photo(id: "", title: "", path: path, thumbnailPath100: "", thumbnailPath350: "", starRating: 0, country: "", area: "", locality: "", dateTimeOriginal: "", addTimestamp: "", lensModel: "", model: "", exposureTime: 0, fNumber: 0, focalLenIn35mmFilm: 0, focalLength: 0, ISOSPEEDRatings: 0, altitude: 0, latitude: 0, longitude: 0, objectName: "", caption: "")
    }
}
