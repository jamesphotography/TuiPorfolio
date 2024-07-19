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
    @Environment(\.presentationMode) var presentationMode
    @State private var position: MapCameraPosition
    var onDismiss: (Int) -> Void
    
    @AppStorage("omitCameraBrand") private var omitCameraBrand = false
    
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
    
    private var currentPhoto: Photo {
        photos[currentIndex]
    }
    
    private var hasGPSData: Bool {
        return currentPhoto.latitude != 0 && currentPhoto.longitude != 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: titleWithBirdNumber, onBackButtonTap: {
                    print("Debug: Back button tapped in DetailView, current index: \(currentIndex)")
                    self.onDismiss(currentIndex)
                    self.presentationMode.wrappedValue.dismiss()
                })
                .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 10) {
                        imageSection(geometry: geometry)
                        controlSection
                        infoSection
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            self.dragOffset = value.translation.width
                        }
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
                
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
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
        .sheet(isPresented: $showingEditor) {
            EditorView(
                image: $image,
                imageName: .constant(currentPhoto.title),
                objectName: $objectName,
                caption: $caption,
                imagePath: .constant(currentPhoto.path),
                thumbnailPath100: .constant(currentPhoto.thumbnailPath100),
                thumbnailPath350: .constant(currentPhoto.thumbnailPath350),
                shouldNavigateToHome: $shouldNavigateToHome
            )
        }
        .sheet(isPresented: $showingShareView) {
            ShareView(photo: currentPhoto)
        }
        .onChange(of: objectName) { oldValue, newValue in
            checkIfBird()
        }
        .onChange(of: shouldNavigateToHome) { oldValue, newValue in
            if newValue {
                handleNavigation()
            }
        }
        .onChange(of: currentIndex) { oldValue, newValue in
            print("Debug: Current index in DetailView changed from \(oldValue) to \(newValue)")
            updateCurrentPhotoInfo()
        }
        .onAppear {
            print("Debug: DetailView appeared with initial index: \(currentIndex)")
            birdList = loadBirdList()
            checkIfBird()
            if isBirdSpecies {
                getBirdNumber()
            }
        }
        .onDisappear {
            print("Debug: DetailView disappeared")
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
        .onTapGesture {
            showingSinglePhotoView = true
        }
    }
    
    private var controlSection: some View {
        HStack {
            Button(action: {
                showingShareView = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            StarRating(rating: currentPhoto.starRating)
            
            Spacer()
            
            Button(action: {
                showingEditor = true
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .padding(.bottom, 4)
            }
            
            InfoRow(icon: "camera", value: formatCameraInfo())
            InfoRow(icon: "dial.min", value: exposureInfo)
            Button(action: {
                navigateToSameday = true
            }) {
                InfoRow(icon: "clock", value: formatDate(currentPhoto.dateTimeOriginal))
            }
            
            if hasGPSData {
                Divider()
                HStack{
                    Spacer()
                    Button(action: {
                        if !currentPhoto.country.isEmpty && !currentPhoto.locality.isEmpty {
                            navigateToMap = true
                        }
                    }) {
                        HStack {
                            if let countryCode = CountryCodeManager.shared.getCountryCode(for: currentPhoto.country) {
                                FlagView(country: countryCode)
                                    .frame(width: 20, height: 15)
                            }
                            Text(locationInfoWithAltitude)
                                .font(.caption2)
                        }
                    }
                    .disabled(currentPhoto.country.isEmpty && currentPhoto.locality.isEmpty)
                    Spacer()
                }
                MiniMapView(position: $position, photo: currentPhoto)
                    .frame(height: 150)
                    .cornerRadius(10)
                    .onTapGesture {
                        navigateToMap = true
                    }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    var exposureInfo: String {
        let formattedExposureTime = formatExposureTime(currentPhoto.exposureTime)
        if formattedExposureTime == "N/A" {
            print("Warning: Invalid exposure time for photo \(currentPhoto.id). Exposure time: \(currentPhoto.exposureTime)")
        }
        return "\(currentPhoto.focalLength)mm f/\(String(format: "%.1f", currentPhoto.fNumber)) \(formattedExposureTime)s ISO\(currentPhoto.ISOSPEEDRatings)"
    }
    
    var locationInfoWithAltitude: String {
        var info = ""
        if !currentPhoto.locality.isEmpty {
            info += currentPhoto.locality
        }
        if !currentPhoto.area.isEmpty {
            if !info.isEmpty {
                info += ", "
            }
            info += currentPhoto.area
        }
        if !currentPhoto.country.isEmpty {
            if !info.isEmpty {
                info += ", "
            }
            info += currentPhoto.country
        }
        if currentPhoto.altitude > 0 {
            if !info.isEmpty {
                info += " • "
            }
            info += "Altitude: \(Int(currentPhoto.altitude))m"
        }
        return info
    }
    
    var titleWithBirdNumber: String {
        if isBirdSpecies, let number = birdNumber {
            return "No.\(number) \(objectName.isEmpty ? currentPhoto.title : objectName)"
        } else {
            return objectName.isEmpty ? currentPhoto.title : objectName
        }
    }
    
    private func showNextImage() {
        if currentIndex < photos.count - 1 {
            currentIndex += 1
            print("Debug: Moved to next image, new index: \(currentIndex)")
        }
    }
    
    private func showPreviousImage() {
        if currentIndex > 0 {
            currentIndex -= 1
            print("Debug: Moved to previous image, new index: \(currentIndex)")
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
    
    func loadImage(from path: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(path).path
        
        if fileManager.fileExists(atPath: fullPath) {
            return UIImage(contentsOfFile: fullPath)
        } else {
            return nil
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
    
    func dateFromString(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: dateString) ?? Date()
    }
    
    func formatExposureTime(_ exposureTime: Double) -> String {
        if exposureTime.isNaN || exposureTime.isInfinite {
            return "N/A"
        }
        
        if exposureTime >= 1 {
            return String(format: "%.1f", exposureTime)
        } else if exposureTime > 0 {
            let denominator = Int(round(1 / exposureTime))
            return "1/\(denominator)"
        } else {
            return "0"
        }
    }
    
    private func loadBirdList() -> [[String]] {
        do {
            guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json") else {
                return []
            }
            
            let data = try Data(contentsOf: url)
            let birdList = try JSONDecoder().decode([[String]].self, from: data)
            return birdList
        } catch {
            print("Debug: Error loading bird list: \(error.localizedDescription)")
            return []
        }
    }
    
    private func checkIfBird() {
        isBirdSpecies = birdList.contains { birdNames in
            birdNames.contains(objectName)
        }
    }
    
    private func getBirdNumber() {
        DispatchQueue.global(qos: .background).async {
            let allObjectNames = SQLiteManager.shared.getAllObjectNames()
            let earliestPhotoTimes = SQLiteManager.shared.getEarliestPhotoTimeForBirds()
            let filteredBirdCounts = allObjectNames.filter { objectName, _ in
                self.birdList.contains { birdNames in
                    birdNames.contains(objectName)
                }
            }
            
            let sortedBirdCounts = filteredBirdCounts.compactMap { (objectName, count) -> (String, String)? in
                if let earliestTime = earliestPhotoTimes.first(where: { $0.0 == objectName })?.1 {
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
    
    private func formatCameraInfo() -> String {
            let cameraModel = omitCameraBrand ? removeBrandName(from: currentPhoto.model) : currentPhoto.model
            let lensModel = omitCameraBrand ? removeBrandName(from: currentPhoto.lensModel) : currentPhoto.lensModel
            return "\(cameraModel) + \(lensModel)"
        }
        
        private func removeBrandName(from model: String) -> String {
            let brandNames = ["Nikon", "Canon", "Sony", "Fujifilm", "Panasonic", "Olympus", "Leica", "Hasselblad", "Pentax", "Sigma", "Tamron", "Zeiss", "Nikkor", "Apple"]
            var result = model
            
            for brand in brandNames {
                if result.lowercased().contains(brand.lowercased()) {
                    result = result.replacingOccurrences(of: brand, with: "", options: [.caseInsensitive, .anchored])
                    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    break  // 只移除第一个匹配的品牌名
                }
            }
            
            return result
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
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)
                Text(value)
                    .font(.caption2)
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
                        .font(.caption2)
                }
            }
        }
    }

    extension DetailView {
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
