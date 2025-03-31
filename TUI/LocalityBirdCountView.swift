import SwiftUI

struct BirdNameInfo: Identifiable, Codable {
    let id: UUID
    let englishName: String
    let chineseName: String
    let thumbnailPath: String
    let matchedName: String
}

struct LocalityBirdCountView: View {
    let area: String
    let birdSpeciesCount: Int
    @State private var birdList: [BirdNameInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var documentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: "\(area) Birds")
                    .padding(.top, geometry.safeAreaInsets.top)

                ScrollView {
                    VStack(spacing: 8) {
                        if isLoading {
                            ProgressView("Loading...")
                                .padding()
                        } else if let error = errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                        } else if birdList.isEmpty {
                            Text("No bird records found")
                                .padding()
                        } else {
                            Text("Found \(birdList.count) bird species")
                                .font(.headline)
                                .padding()

                            ForEach(birdList) { bird in
                                NavigationLink(destination: ObjectNameView(objectName: bird.matchedName)) {
                                    HStack {
                                        AsyncImage(url: getFullImagePath(for: bird.thumbnailPath)) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                            case .success(let image):
                                                image.resizable()
                                            case .failure:
                                                Image(systemName: "exclamationmark.triangle")
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(5)
                                        
                                        VStack(alignment: .leading) {
                                            Text(bird.matchedName)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text(bird.matchedName == bird.englishName ? bird.chineseName : bird.englishName)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .background(Color("BGColor"))

                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .background(Color("BGColor").edgesIgnoringSafeArea(.all))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadBirdListWithCache)
    }

    private func loadBirdListWithCache() {
        isLoading = true
        errorMessage = nil

        if let cachedData = getCachedData(), !shouldRefreshCache() {
            self.birdList = cachedData
            self.isLoading = false
            return
        }

        DispatchQueue.global(qos: .background).async {
            do {
                let fullBirdInfo = try loadBirdInfoList()
                let areaPhotos = SQLiteManager.shared.getBirdPhotosForArea(area: area)
                
                var birdNameInfoList: [BirdNameInfo] = []

                for birdNames in fullBirdInfo {
                    if birdNames.count >= 2 {
                        let englishName = birdNames[0]
                        let chineseName = birdNames[1]
                        
                        if let matchedPhoto = areaPhotos.first(where: { $0.objectName == englishName || $0.objectName == chineseName }) {
                            birdNameInfoList.append(BirdNameInfo(
                                id: UUID(),
                                englishName: englishName,
                                chineseName: chineseName,
                                thumbnailPath: matchedPhoto.thumbnailPath100,
                                matchedName: matchedPhoto.objectName
                            ))
                        }
                    }
                }
                
                let sortedList = birdNameInfoList.sorted { $0.englishName < $1.englishName }
                
                DispatchQueue.main.async {
                    self.birdList = sortedList
                    self.isLoading = false
                    self.cacheData(sortedList)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func loadBirdInfoList() throws -> [[String]] {
        guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json") else {
            throw NSError(domain: "LocalityBirdCountView", code: 1, userInfo: [NSLocalizedDescriptionKey: "birdInfo.json file not found"])
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([[String]].self, from: data)
    }
    
    private func getFullImagePath(for relativePath: String) -> URL {
        return documentDirectory.appendingPathComponent(relativePath)
    }

    // 缓存相关方法
    private func cacheData(_ data: [BirdNameInfo]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(data) {
            UserDefaults.standard.set(encoded, forKey: "CachedBirdList_\(area)")
            UserDefaults.standard.set(Date(), forKey: "LastCacheTime_\(area)")
        }
    }

    private func getCachedData() -> [BirdNameInfo]? {
        if let savedData = UserDefaults.standard.object(forKey: "CachedBirdList_\(area)") as? Data {
            let decoder = JSONDecoder()
            if let loadedData = try? decoder.decode([BirdNameInfo].self, from: savedData) {
                return loadedData
            }
        }
        return nil
    }

    private func shouldRefreshCache() -> Bool {
        guard let lastCacheTime = UserDefaults.standard.object(forKey: "LastCacheTime_\(area)") as? Date else {
            return true
        }
        let currentTime = Date()
        let timeDifference = currentTime.timeIntervalSince(lastCacheTime)
        return timeDifference > 3600 // 60 minutes in seconds
    }
}

struct LocalityBirdCountView_Previews: PreviewProvider {
    static var previews: some View {
        LocalityBirdCountView(area: "Sample Area", birdSpeciesCount: 10)
    }
}
