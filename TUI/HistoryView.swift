import SwiftUI
import Charts

struct PhotoStats {
    let userName: String
    let totalDays: Int
    let years: Int
    let months: Int
    let days: Int
    let totalPhotos: Int
    let totalCountries: Int
    let totalRegions: Int
    let totalCameras: Int
    let totalLenses: Int
    let cameraUsage: [EquipmentUsage]
    let lensUsage: [EquipmentUsage]
}

struct EquipmentUsage: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct HistoryView: View {
    @State private var photoStats: PhotoStats?
    @State private var selectedChart: ChartType = .camera
    @State private var showCopyAlert = false
    @State private var showCameraCountView = false
    @State private var showLensCountView = false

    enum ChartType {
        case camera
        case lens
    }
    
    let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow, .gray, .cyan, .indigo]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: NSLocalizedString("Photographer's Journey", comment: ""))
                    .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 5) {
                        if let stats = photoStats {
                            HistoryCardView(stats: stats)
                                .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.6)
                                .onLongPressGesture {
                                    UIPasteboard.general.string = generateCopyText(stats: stats)
                                    showCopyAlert = true
                                }
                        } else {
                            Text(NSLocalizedString("Loading statistics...", comment: ""))
                                .font(.largeTitle)
                                .padding()
                        }
                        Spacer()

                        if let stats = photoStats {
                            VStack {
                                Picker("Chart Type", selection: $selectedChart) {
                                    Text(NSLocalizedString("Cameras", comment: "")).tag(ChartType.camera)
                                    Text(NSLocalizedString("Lenses", comment: "")).tag(ChartType.lens)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding()

                                Chart {
                                    ForEach(Array(zip((selectedChart == .camera ? stats.cameraUsage : stats.lensUsage).prefix(10), colors)), id: \.0.id) { item, color in
                                        SectorMark(
                                            angle: .value("Usage", item.count),
                                            innerRadius: .ratio(0.618),
                                            angularInset: 1.5
                                        )
                                        .foregroundStyle(color)
                                        .annotation(position: .overlay) {
                                            Text("\(item.count)")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .frame(height: 400)
                                .padding()
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(zip((selectedChart == .camera ? stats.cameraUsage : stats.lensUsage).prefix(10), colors)), id: \.0.id) { item, color in
                                        HStack {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 10, height: 10)
                                            Text(item.name)
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                .padding()
                                
                                Button(action: {
                                    if selectedChart == .camera {
                                        showCameraCountView = true
                                    } else {
                                        showLensCountView = true
                                    }
                                }) {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 32))
                                        .padding(5)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                }
                                .padding(10)
                            }
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.all, 20)
                    .background(Color("BGColor"))
                }

                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear(perform: loadPhotoStats)
        .alert(isPresented: $showCopyAlert) {
            Alert(title: Text(NSLocalizedString("Copied", comment: "")),
                  message: Text(NSLocalizedString("Statistics have been copied to clipboard.", comment: "")),
                  dismissButton: .default(Text(NSLocalizedString("OK", comment: ""))))
        }
        .sheet(isPresented: $showCameraCountView) {
            CameraCountView()
        }
        .sheet(isPresented: $showLensCountView) {
            LensCountView()
        }
    }
    
    func loadPhotoStats() {
        let photos = SQLiteManager.shared.getPhotoHistory()
        
        guard !photos.isEmpty else {
            print("No photos found in the database.")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let dates = photos.compactMap { photo in
            dateFormatter.date(from: photo.dateTimeOriginal)
        }
        
        guard let firstPhotoDate = dates.min(), let lastPhotoDate = dates.max() else {
            print("Could not determine first or last photo date.")
            return
        }
        
        let totalDays = Calendar.current.dateComponents([.day], from: firstPhotoDate, to: lastPhotoDate).day ?? 0
        
        let years = totalDays / 365
        let months = (totalDays % 365) / 30
        let days = (totalDays % 365) % 30
        
        let totalPhotos = photos.count
        let countries = Set(photos.map { $0.country }).count
        let regions = Set(photos.map { $0.locality }).count
        
        var cameraUsage = [String: Int]()
        var lensUsage = [String: Int]()
        
        for photo in photos {
            let cameraModel = refineModelName(photo.model)
            let lensModel = refineModelName(photo.lensModel)
            cameraUsage[cameraModel, default: 0] += 1
            lensUsage[lensModel, default: 0] += 1
        }
        
        let cameraUsageArray = cameraUsage.map { EquipmentUsage(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(10)
        let lensUsageArray = lensUsage.map { EquipmentUsage(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(10)
        
        let userName = UserDefaults.standard.string(forKey: "userName") ?? NSLocalizedString("Photographer", comment: "")
        
        photoStats = PhotoStats(
            userName: userName,
            totalDays: totalDays,
            years: years,
            months: months,
            days: days,
            totalPhotos: totalPhotos,
            totalCountries: countries,
            totalRegions: regions,
            totalCameras: cameraUsage.count,
            totalLenses: lensUsage.count,
            cameraUsage: Array(cameraUsageArray),
            lensUsage: Array(lensUsageArray)
        )
    }
    
    func refineModelName(_ name: String) -> String {
        let brandNames = ["Nikon", "Canon", "Sony", "Nikkor", "Sigma", "Tamron", "Fujifilm", "Olympus", "Panasonic", "Leica"]
        var refinedName = name
        
        for brand in brandNames {
            if refinedName.lowercased().contains(brand.lowercased()) {
                refinedName = refinedName.replacingOccurrences(of: brand, with: "", options: [.caseInsensitive])
            }
        }
        
        return refinedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func generateCopyText(stats: PhotoStats) -> String {
        let timePeriod = formatTimePeriod(years: stats.years, months: stats.months, days: stats.days)
        return String(format: NSLocalizedString("""
        Photographer's Journey:
        In %d days, %@, you've captured %@ of moments. Each press of the shutter is a testament to your passion and dedication to photography.
        You've used %d cameras and %d lenses to capture %d stunning photos, each telling a unique story.
        Your lens has spanned %d countries and %d regions, bringing the world closer.
        .
        """, comment: ""),
        stats.totalDays,
        stats.userName,
        timePeriod,
        stats.totalCameras,
        stats.totalLenses,
        stats.totalPhotos,
        stats.totalCountries,
        stats.totalRegions)
    }
    
    func formatTimePeriod(years: Int, months: Int, days: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 3
        
        var dateComponents = DateComponents()
        dateComponents.year = years > 0 ? years : nil
        dateComponents.month = months > 0 ? months : nil
        dateComponents.day = days > 0 ? days : nil
        
        return formatter.string(from: dateComponents) ?? ""
    }
}

struct HistoryCardView: View {
    var stats: PhotoStats
    
    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text(String(format: NSLocalizedString("In %d days, %@, you've captured %@ of moments. Each press of the shutter is a testament to your passion and dedication to photography.", comment: ""),
                            stats.totalDays,
                            stats.userName,
                            formatTimePeriod(years: stats.years, months: stats.months, days: stats.days)))
                Text(String(format: NSLocalizedString("You've used %d cameras and %d lenses to capture %d stunning photos, each telling a unique story.", comment: ""), stats.totalCameras, stats.totalLenses, stats.totalPhotos))
                Text(String(format: NSLocalizedString("Your lens has spanned %d countries and %d regions, bringing the world closer.", comment: ""), stats.totalCountries, stats.totalRegions))
            }
            .padding(.horizontal, 15)
            .foregroundColor(.white)
            .font(.title2)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 20)
            Image("tuiblueapp")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            Spacer()
        }
        .padding(.vertical, 20)
        .background(Color("TUIBLUE"))
        .cornerRadius(15)
        .shadow(radius: 10)
    }
    
    func formatTimePeriod(years: Int, months: Int, days: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 3
        
        var dateComponents = DateComponents()
        dateComponents.year = years > 0 ? years : nil
        dateComponents.month = months > 0 ? months : nil
        dateComponents.day = days > 0 ? days : nil
        
        return formatter.string(from: dateComponents) ?? ""
    }
}
