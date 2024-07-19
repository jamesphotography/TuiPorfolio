import SwiftUI
import Charts

struct PhotoStats {
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

    enum ChartType {
        case camera
        case lens
    }
    
    let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .yellow, .gray, .cyan, .indigo]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部导航栏
                HeadBarView(title: "Photographer's Journey")
                    .padding(.top, geometry.safeAreaInsets.top)
                
                // 主体内容区域
                ScrollView {
                    VStack(spacing: 20) {
                        if let stats = photoStats {
                            HistoryCardView(stats: stats)
                                .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.6)
                        } else {
                            Text("Loading statistics...")
                                .font(.largeTitle)
                                .padding()
                        }
                        Spacer()
                        // 应用图标
                        Image("tuiapp")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .padding()
                        // 图表
                        if let stats = photoStats {
                            VStack {
                                Picker("Chart Type", selection: $selectedChart) {
                                    Text("Cameras").tag(ChartType.camera)
                                    Text("Lenses").tag(ChartType.lens)
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
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .frame(height: 300)
                                .padding()
                                
                                // 图例
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(Array(zip((selectedChart == .camera ? stats.cameraUsage : stats.lensUsage).prefix(10), colors)), id: \.0.id) { item, color in
                                        HStack {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 10, height: 10)
                                            Text(item.name)
                                                .font(.caption)
                                        }
                                    }
                                }
                                .padding()
                            }
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color("BGColor"))
                }

                // 底部导航栏
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear(perform: loadPhotoStats)
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
        
        // Calculate camera and lens usage
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
        
        photoStats = PhotoStats(
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
}

struct HistoryCardView: View {
    var stats: PhotoStats
    
    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                let timeText: String = {
                    var text = ""
                    if stats.years > 0 { text += "\(stats.years) years" }
                    if stats.months > 0 {
                        if !text.isEmpty { text += " " }
                        text += "\(stats.months) months"
                    }
                    if stats.days > 0 {
                        if !text.isEmpty { text += " " }
                        text += "\(stats.days) days"
                    }
                    return text
                }()
                
                Text("In these \(stats.totalDays) days, you've captured \(timeText) of moments. Each press of the shutter is a testament to your passion and dedication to photography.")
                    .foregroundColor(.white)
                Spacer()
                Text("You've taken \(stats.totalPhotos) stunning photos, each telling a unique story.")
                    .foregroundColor(.white)
                Spacer()
                Text("Your lens has spanned \(stats.totalCountries) countries and \(stats.totalRegions) regions, bringing the world closer through your eyes.")
                    .foregroundColor(.white)
                Spacer()
                Text("You've used \(stats.totalCameras) cameras and \(stats.totalLenses) lenses to capture these memories, each tool adding its unique touch to your art.")
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 20)
        }
        .padding(.vertical, 20)
        .background(Color("TUIBLUE").opacity(0.8))
        .cornerRadius(15)
        .shadow(radius: 10)
    }
}
