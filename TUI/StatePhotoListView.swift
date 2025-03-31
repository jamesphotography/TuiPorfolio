import SwiftUI

struct StatePhotoListView: View {
    let area: String
    @State private var photos: [Photo] = []
    @State private var displayedPhotos: [Photo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var birdSpeciesCount: Int = 0
    @State private var totalPhotoCount: Int = 0
    @State private var currentPage = 0
    @State private var birdNumbers: [String: Int] = [:]
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    private let itemsPerPage = 30
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: area)
                    .padding(.top, geometry.safeAreaInsets.top)
                
                ScrollView {
                    VStack(spacing: 10) {
                        // Statistics Header
                        HStack(spacing: 15) {
                            Text("\(totalPhotoCount) Photos")
                                .font(.headline)
                                .foregroundColor(Color("TUIBLUE"))
                            
                            if enableBirdWatching {
                                Text("\(birdSpeciesCount) Birds")
                                    .font(.headline)
                                    .foregroundColor(Color("TUIBLUE"))
                            }
                        }
                        .padding(.vertical, 5)
                        
                        // Photo List
                        LazyVStack(spacing: 8) {
                            ForEach(displayedPhotos) { photo in
                                NavigationLink(destination: DetailView(photo: photo)) {
                                    BirdListItemView(photo: photo,
                                                   number: enableBirdWatching ? (birdNumbers[photo.objectName] ?? 0) : nil)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
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
                            Text(enableBirdWatching ? "No bird photos in this area" : "No photos in this area")
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
    
    private func loadPhotos() {
        isLoading = true
        
        // 加载该地区的所有照片
        var areaPhotos = SQLiteManager.shared.getAllPhotos().filter { $0.area == area }
        
        // 只在启用鸟类观察时过滤鸟类照片
        if enableBirdWatching {
            areaPhotos = areaPhotos.filter { !$0.objectName.isEmpty && isBirdSpecies($0.objectName) }
            calculateBirdNumbers(from: areaPhotos)
            
            let uniqueBirdSpecies = Set(areaPhotos.map { $0.objectName })
            birdSpeciesCount = uniqueBirdSpecies.count
        }
        
        // 按照拍摄时间排序
        photos = areaPhotos.sorted { $0.dateTimeOriginal > $1.dateTimeOriginal }
        totalPhotoCount = areaPhotos.count
        
        loadMorePhotos()
        isLoading = false
    }
    
    private func calculateBirdNumbers(from photos: [Photo]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let groupedPhotos = Dictionary(grouping: photos) { $0.objectName }
        let sortedSpecies = groupedPhotos.map { (species, photos) -> (String, Date) in
            let earliestPhoto = photos.min { photo1, photo2 in
                photo1.dateTimeOriginal < photo2.dateTimeOriginal
            }
            let date = dateFormatter.date(from: earliestPhoto?.dateTimeOriginal ?? "") ?? Date()
            return (species, date)
        }.sorted { $0.1 < $1.1 }
        
        for (index, (species, _)) in sortedSpecies.enumerated() {
            birdNumbers[species] = index + 1
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

struct BirdListItemView: View {
    let photo: Photo
    let number: Int?
    
    var body: some View {
        HStack(spacing: 12) {
            // 缩略图
            if let uiImage = loadImage(from: photo.thumbnailPath100) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
            }
            
            // 照片信息
            VStack(alignment: .leading, spacing: 4) {
                // 第一行：序号（如果有）和标题
                HStack {
                    if let number = number {
                        Text("\(number)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    Text(photo.objectName.isEmpty ? photo.title : photo.objectName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                // 第二行：拍摄时间和地点
                Text("\(formatDate(photo.dateTimeOriginal)) \(photo.locality)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.blue)
                .font(.system(size: 14))
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
    
    private func loadImage(from path: String) -> UIImage? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL.appendingPathComponent(path).path
        
        if fileManager.fileExists(atPath: fullPath) {
            return UIImage(contentsOfFile: fullPath)
        }
        return nil
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yy-MM-dd HH:mm"
        
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }
}
