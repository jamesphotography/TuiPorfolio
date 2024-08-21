import SwiftUI
import MapKit

struct DetailView: View {
    let photos: [Photo]
    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
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
    var onDismiss: (Int) -> Void
    
    private var currentPhoto: Photo { photos[currentIndex] }
    private var hasGPSData: Bool { currentPhoto.latitude != 0 && currentPhoto.longitude != 0 }
    
    init(photos: [Photo], initialIndex: Int, onDismiss: @escaping (Int) -> Void) {
        self.photos = photos
        self._currentIndex = State(initialValue: initialIndex)
        let initialPhoto = photos[initialIndex]
        self._objectName = State(initialValue: initialPhoto.objectName)
        self._caption = State(initialValue: initialPhoto.caption)
        self.onDismiss = onDismiss
        let coordinate = CLLocationCoordinate2D(latitude: initialPhoto.latitude, longitude: initialPhoto.longitude)
        self._position = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
        self._birdList = State(initialValue: [])
        self._birdNumber = State(initialValue: nil)
        self._image = State(initialValue: loadImage(from: initialPhoto.path))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: titleWithBirdNumber, onBackButtonTap: {
                    self.onDismiss(currentIndex)
                    self.presentationMode.wrappedValue.dismiss()
                })
                .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 10) {
                        imageSection(geometry: geometry)
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
                    latitude: currentPhoto.latitude,
                    longitude: currentPhoto.longitude,
                    country: currentPhoto.country,
                    locality: currentPhoto.locality,
                    thumbnailPath: currentPhoto.thumbnailPath100,
                    showMap: $showMap
                )
            }
        }
        .navigationDestination(isPresented: $navigateToSameday) {
            CalendarView(date: dateFromString(currentPhoto.dateTimeOriginal))
        }
        .navigationDestination(isPresented: $navigateToCamera) {
            CameraDetailView(cameraModel: currentPhoto.model)
        }
        .navigationDestination(isPresented: $navigateToLens) {
            LensDetailView(lensModel: currentPhoto.lensModel)
        }
        .sheet(isPresented: $showingEditor) {
            EditorView(
                image: $image,
                imageName: .constant(currentPhoto.title),
                objectName: $objectName,
                caption: $caption,
                imagePath: .constant(currentPhoto.path),
                thumbnailPath100: .constant(currentPhoto.thumbnailPath100),
                thumbnailPath350: .constant(currentPhoto.thumbnailPath350),
                shouldNavigateToHome: $shouldNavigateToHome,
                initialRating: currentPhoto.starRating,
                initialLatitude: currentPhoto.latitude,
                initialLongitude: currentPhoto.longitude,
                initialCountry: currentPhoto.country,
                initialArea: currentPhoto.area,
                initialLocality: currentPhoto.locality
            )
        }
        .sheet(isPresented: $showingShareView) {
            ShareView(photo: currentPhoto)
        }
        .onChange(of: objectName) { _, _ in checkIfBird() }
        .onChange(of: shouldNavigateToHome) { _, newValue in
            if newValue { handleNavigation() }
        }
        .onChange(of: currentIndex) { _, _ in updateCurrentPhotoInfo() }
        .onAppear {
            birdList = loadBirdList()
            checkIfBird()
        }
        .onChange(of: enableBirdWatching) { _, _ in
            checkIfBird()
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
    
    private func updateCurrentPhotoInfo() {
        objectName = currentPhoto.objectName
        caption = currentPhoto.caption
        image = loadImage(from: currentPhoto.path)
        position = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: currentPhoto.latitude, longitude: currentPhoto.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        checkIfBird()
        if isBirdSpecies {
            getBirdNumber()
        }
    }
    
    private func imageSection(geometry: GeometryProxy) -> some View {
        ZStack {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width)
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 10)
                    .offset(x: self.dragOffset)
                    .animation(.interactiveSpring(), value: dragOffset)
            } else {
                Text("Image could not be loaded")
                    .foregroundColor(.red)
            }
        }
        .onTapGesture { showingSinglePhotoView = true }
        .gesture(DragGesture()
            .onChanged { self.dragOffset = $0.translation.width }
            .onEnded { value in
                let threshold = geometry.size.width * 0.2
                if value.translation.width > threshold {
                    self.showPreviousImage()
                } else if value.translation.width < -threshold {
                    self.showNextImage()
                }
                self.dragOffset = 0
            }
        )
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
                    Text(EXIFManager.shared.formatDate(currentPhoto.dateTimeOriginal))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                Spacer()
                StarRating(rating: currentPhoto.starRating)
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
    
    private func deletePhoto() {
        // 删除文件
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fullPath = documentsPath.appendingPathComponent(currentPhoto.path)
        
        do {
            try fileManager.removeItem(at: fullPath)
           // print("File deleted successfully")
            
            // 删除数据库记录
            SQLiteManager.shared.deletePhotoRecord(imagePath: currentPhoto.path)
            
            // 显示删除成功的提示框
            showingDeleteSuccessAlert = true
        } catch {
            print("Error deleting file: \(error)")
        }
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
                InfoRow(icon: "camera.viewfinder", value: currentPhoto.model)
                    .underline()
            }
            Button(action: { navigateToLens = true }) {
                InfoRow(icon: "button.programmable.square", value: currentPhoto.lensModel)
                    .underline()
            }
            InfoRow(icon: "camera.aperture", value: EXIFManager.shared.exposureInfo(photo: currentPhoto))
            
            if hasGPSData {
                Divider()
                HStack {
                    Spacer()
                    Button(action: {
                        if !currentPhoto.country.isEmpty && !currentPhoto.locality.isEmpty {
                            navigateToMap = true
                        }
                    }) {
                        HStack {
                            if let countryCode = CountryCodeManager.shared.getCountryCode(for: currentPhoto.country) {
                                FlagView(country: countryCode)
                                    .frame(width: 20, height: 30)
                            }
                            Text(EXIFManager.shared.locationInfoWithAltitude(photo: currentPhoto))
                                .font(.caption)
                        }
                    }
                    .disabled(currentPhoto.country.isEmpty && currentPhoto.locality.isEmpty)
                    Spacer()
                }
                MiniMapView(position: $position, photo: currentPhoto)
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
            return "No.\(number) \(objectName.isEmpty ? currentPhoto.title : objectName)"
        } else {
            return objectName.isEmpty ? currentPhoto.title : objectName
        }
    }
    
    private func showNextImage() {
        if currentIndex < photos.count - 1 {
            currentIndex += 1
        }
    }
    
    private func showPreviousImage() {
        if currentIndex > 0 {
            currentIndex -= 1
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
        var exifInfo = EXIFManager.shared.copyEXIFInfo(for: currentPhoto)
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

struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePhoto = Photo(
            id: "1",
            title: "茶色蛙口夜鷹",
            path: "testImage",
            thumbnailPath100: "testImage_thumb100",
            thumbnailPath350: "testImage_thumb350",
            starRating: 5,
            country: "Australia",
            area: "Victoria",
            locality: "Parkville",
            dateTimeOriginal: "2024-08-05 13:15",
            addTimestamp: "2024-08-05 13:20",
            lensModel: "NIKKOR Z 400mm f/4.5 VR S Z TC-1.4x",
            model: "NIKON Z 8",
            exposureTime: 1/2000,
            fNumber: 6.3,
            focalLenIn35mmFilm: 560.0,
            focalLength: 560.0,
            ISOSPEEDRatings: 3200,
            altitude: 48,
            latitude: -37.7964,
            longitude: 144.9612,
            objectName: "茶色蛙口夜鷹",
            caption: "英文名：Tawny Frogmouth (学名：Podargus strigoides)，是蛙口夜鹰目蛙口夜鹰科蛙口夜鹰属的鸟类。又名：褐蛙口鹰、茶色蛙口鹰、茶色夜鹰，是分布于澳大利亚和塔斯曼尼亚的特有鸟类。以大头、宽嘴和独特的黄色眼睛著称，能够巧妙地融入树皮背景，展现出高超的伪装技巧。这种鸟广泛分布于各种生境，包括城市郊区。"
        )
        
        DetailView(photos: [samplePhoto], initialIndex: 0) { _ in }
    }
}
