import SwiftUI
import MapKit

struct DetailView: View {
    let photo: Photo
    @State private var showingEditor = false
    @State private var image: UIImage?
    @State private var objectName: String
    @State private var caption: String
    @State private var shouldNavigateToHome = false
    @State private var showingShareView = false
    @State private var navigateToMap = false
    @State private var showMap = false
    @State private var navigateToSameday = false
    @State private var isBirdSpecies: Bool = false
    @State private var birdList: [[String]] = []
    @State private var birdNumber: Int?
    @State private var showingSinglePhotoView = false
    @State private var showingCopyAlert = false
    @Environment(\.presentationMode) var presentationMode
    @State private var position: MapCameraPosition
    @State private var navigateToCamera = false
    @State private var navigateToLens = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteSuccessAlert = false
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    
    private var hasGPSData: Bool { photo.latitude != 0 && photo.longitude != 0 }
    
    init(photo: Photo) {
        self.photo = photo
        self._objectName = State(initialValue: photo.objectName)
        self._caption = State(initialValue: photo.caption)
        let coordinate = CLLocationCoordinate2D(latitude: photo.latitude, longitude: photo.longitude)
        self._position = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
        self._image = State(initialValue: loadImage(from: photo.path))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: titleWithBirdNumber, onBackButtonTap: {
                    self.presentationMode.wrappedValue.dismiss()
                })
                .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 10) {
                        imageSection
                        controlSection
                        infoSection
                            .gesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in copyEXIFInfo() })
                    }
                }
                
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .alert(isPresented: $showingCopyAlert) {
                Alert(title: Text("Copy Successful"), message: Text("EXIF information has been copied to the clipboard"), dismissButton: .default(Text("OK")))
            }
            .alert("Photo Deleted", isPresented: $showingDeleteSuccessAlert) {
                Button("OK") {
                    self.presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("The photo has been deleted successfully. Please tap the Tui logo to refresh the main page.")
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingSinglePhotoView) {
            if let image = self.image {
                SinglePhotoView(image: image)
            }
        }
        .navigationDestination(isPresented: $navigateToMap) {
            if hasGPSData {
                MapView(
                    latitude: photo.latitude,
                    longitude: photo.longitude,
                    country: photo.country,
                    locality: photo.locality,
                    thumbnailPath: photo.thumbnailPath100,
                    showMap: $showMap
                )
            }
        }
        .navigationDestination(isPresented: $navigateToSameday) {
            CalendarView(date: dateFromString(photo.dateTimeOriginal))
        }
        .navigationDestination(isPresented: $navigateToCamera) {
            CameraDetailView(cameraModel: photo.model)
        }
        .navigationDestination(isPresented: $navigateToLens) {
            LensDetailView(lensModel: photo.lensModel)
        }
        .sheet(isPresented: $showingEditor) {
            EditorView(
                image: $image,
                imageName: .constant(photo.title),
                objectName: $objectName,
                caption: $caption,
                imagePath: .constant(photo.path),
                thumbnailPath100: .constant(photo.thumbnailPath100),
                thumbnailPath350: .constant(photo.thumbnailPath350),
                shouldNavigateToHome: $shouldNavigateToHome,
                initialRating: photo.starRating,
                initialLatitude: photo.latitude,
                initialLongitude: photo.longitude,
                initialCountry: photo.country,
                initialArea: photo.area,
                initialLocality: photo.locality
            )
        }
        .sheet(isPresented: $showingShareView) {
            ShareView(photo: photo)
        }
        .onChange(of: objectName) { _, _ in checkIfBird() }
        .onChange(of: shouldNavigateToHome) { _, newValue in
            if newValue { handleNavigation() }
        }
        .onAppear {
            birdList = loadBirdList()
            checkIfBird()
        }
        .onChange(of: enableBirdWatching) { _, _ in
            checkIfBird()
        }
    }
    
    private var imageSection: some View {
        Group {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 10)
            } else {
                Text("Image could not be loaded")
                    .foregroundColor(.red)
            }
        }
        .onTapGesture { showingSinglePhotoView = true }
    }
    
    private var controlSection: some View {
        HStack {
            Button(action: { showingShareView = true }) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .foregroundColor(.blue)
            }
            Button(action: { copyEXIFInfo() }) {
                Image(systemName: "doc.circle.fill")
                    .foregroundColor(.blue)
            }
            Spacer()
            VStack {
                Button(action: { navigateToSameday = true }) {
                    Text(EXIFManager.shared.formatDate(photo.dateTimeOriginal))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                Spacer()
                StarRating(rating: photo.starRating)
            }
            Spacer()
            Button(action: { showingEditor = true }) {
                Image(systemName: "square.and.pencil.circle.fill")
                    .foregroundColor(.blue)
            }
            
            Button(action: { showingDeleteAlert = true }) {
                Image(systemName: "trash.circle.fill")
                    .foregroundColor(Color("Flare"))
            }
            .alert("Delete Photo", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deletePhoto() }
            } message: {
                Text("Are you sure you want to delete this photo? This action cannot be undone.")
            }
        }
        .padding(.horizontal)
        .font(.title)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !caption.isEmpty {
                Text(caption)
                    .font(.body)
                    .padding(.bottom, 10)
                    .tracking(0.4)
                    .lineSpacing(6)
            }
            
            Button(action: { navigateToCamera = true }) {
                InfoRow(icon: "camera.viewfinder", value: photo.model)
                    .underline()
            }
            Button(action: { navigateToLens = true }) {
                InfoRow(icon: "button.programmable.square", value: photo.lensModel)
                    .underline()
            }
            InfoRow(icon: "camera.aperture", value: EXIFManager.shared.exposureInfo(photo: photo))
            
            if hasGPSData {
                Divider()
                HStack {
                    Spacer()
                    Button(action: {
                        if !photo.country.isEmpty && !photo.locality.isEmpty {
                            navigateToMap = true
                        }
                    }) {
                        HStack {
                            if let countryCode = CountryCodeManager.shared.getCountryCode(for: photo.country) {
                                FlagView(country: countryCode)
                                    .frame(width: 20, height: 30)
                            }
                            Text(EXIFManager.shared.locationInfoWithAltitude(photo: photo))
                                .font(.caption)
                        }
                    }
                    .disabled(photo.country.isEmpty && photo.locality.isEmpty)
                    Spacer()
                }
                MiniMapView(position: $position, photo: photo)
                    .frame(height: 150)
                    .cornerRadius(10)
                    .onTapGesture { navigateToMap = true }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var titleWithBirdNumber: String {
        if enableBirdWatching && isBirdSpecies, let number = birdNumber {
            return "No.\(number) \(objectName.isEmpty ? photo.title : objectName)"
        } else {
            return objectName.isEmpty ? photo.title : objectName
        }
    }
    
    private func loadImage(from path: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(path).path
        
        if fileManager.fileExists(atPath: fullPath) {
            return UIImage(contentsOfFile: fullPath)
        } else {
            return nil
        }
    }
    
    private func deletePhoto() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 删除原始图片
        let fullPath = documentsPath.appendingPathComponent(photo.path)
        // 删除缩略图
        let thumbnail100Path = documentsPath.appendingPathComponent(photo.thumbnailPath100)
        let thumbnail350Path = documentsPath.appendingPathComponent(photo.thumbnailPath350)
        
        do {
            try fileManager.removeItem(at: fullPath)
            try fileManager.removeItem(at: thumbnail100Path)
            try fileManager.removeItem(at: thumbnail350Path)
            
            // 从数据库中删除记录
            SQLiteManager.shared.deletePhotoRecord(imagePath: photo.path)
            
            // 刷新缓存
            SQLiteManager.shared.invalidateCache()
            
            // 如果有其他相关缓存，也应该在这里刷新
            BirdCountCache.shared.clear()
            
            // 发送通知，告知其他视图数据已更新
            NotificationCenter.default.post(name: .photoDeleted, object: nil)
            
            showingDeleteSuccessAlert = true
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    private func dateFromString(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: dateString) ?? Date()
    }
    
    private func loadBirdList() -> [[String]] {
        do {
            guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json") else {
                return []
            }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([[String]].self, from: data)
        } catch {
            print("Debug: Error loading bird list: \(error.localizedDescription)")
            return []
        }
    }
    
    private func checkIfBird() {
        guard enableBirdWatching else {
            isBirdSpecies = false
            birdNumber = nil
            return
        }
        isBirdSpecies = birdList.contains { birdNames in
            birdNames.contains(objectName)
        }
        if isBirdSpecies {
            getBirdNumber()
        } else {
            birdNumber = nil
        }
    }
    
    private func copyEXIFInfo() {
        var exifInfo = EXIFManager.shared.copyEXIFInfo(for: photo)
        if enableBirdWatching && isBirdSpecies, let number = birdNumber {
            exifInfo += "\nBird ID:No.\(number)"
        }
        UIPasteboard.general.string = exifInfo
        showingCopyAlert = true
    }
    
    private func getBirdNumber() {
        guard enableBirdWatching && isBirdSpecies else {
            birdNumber = nil
            return
        }
        DispatchQueue.global(qos: .background).async {
            let allObjectNames = SQLiteManager.shared.getAllObjectNames()
            let earliestPhotoTimes = SQLiteManager.shared.getEarliestPhotoTimeForBirds()
            let filteredBirdCounts = allObjectNames.filter { objectName, _ in
                self.birdList.contains { birdNames in
                    birdNames.contains(objectName)
                }
            }
            
            let sortedBirdCounts = filteredBirdCounts.compactMap { (objectName, count) -> (String, String)? in
                if let earliestTime = earliestPhotoTimes.first(where: {$0.0 == objectName })?.1 {
                    return (objectName, earliestTime)
                }
                return nil
            }.sorted { $0.1 < $1.1 }
            
            if let index = sortedBirdCounts.firstIndex(where: { $0.0 == self.objectName }) {
                DispatchQueue.main.async {
                    self.birdNumber = index + 1
                }
            }
        }
    }
    
    func handleNavigation() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let _ = window.rootViewController {
            let contentView = ContentView()
            let hostingController = UIHostingController(rootView: contentView)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
        } else {
            print("DetailView: Unable to find root view controller")
        }
        presentationMode.wrappedValue.dismiss()
    }
}

struct MiniMapView: View {
    @Binding var position: MapCameraPosition
    let photo: Photo
    
    var body: some View {
        Map(position: $position) {
            Marker(photo.objectName.isEmpty ? "Photo Location" : photo.objectName,
                   coordinate: CLLocationCoordinate2D(latitude: photo.latitude, longitude: photo.longitude))
            .tint(.blue)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color("TUIBLUE"))
                .frame(width: 20, height: 20)
            Text(value)
                .font(.subheadline)
        }
    }
}

struct StarRating: View {
    let rating: Int
    
    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundColor(index <= rating ? .yellow : .gray)
                    .font(.system(size: 12, weight: .regular, design: .default))
            }
        }
    }
}

// 预览提供者
struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePhoto = Photo(
            id: "1",
            title: "Sample Photo",
            path: "samplePath",
            thumbnailPath100: "sampleThumb100",
            thumbnailPath350: "sampleThumb350",
            starRating: 4,
            country: "Sample Country",
            area: "Sample Area",
            locality: "Sample Locality",
            dateTimeOriginal: "2023-08-21 12:00:00",
            addTimestamp: "2023-08-21 12:05:00",
            lensModel: "Sample Lens",
            model: "Sample Camera",
            exposureTime: 1/100,
            fNumber: 2.8,
            focalLenIn35mmFilm: 50.0,
            focalLength: 50.0,
            ISOSPEEDRatings: 100,
            altitude: 100,
            latitude: 0,
            longitude: 0,
            objectName: "Sample Object",
            caption: "This is a sample caption for preview purposes."
        )
        
        DetailView(photo: samplePhoto)
    }
}


extension Notification.Name {
    static let photoDeleted = Notification.Name("photoDeleted")
}
