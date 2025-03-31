import SwiftUI

struct LocalityListView: View {
    let countryName: String
    @State private var groupedLocalities: [(area: String, totalPhotos: Int, birdSpeciesCount: Int, localities: [LocalityData])] = []
    @State private var totalBirdSpeciesCount: Int = 0
    @AppStorage("enableBirdWatching") private var enableBirdWatching = false
    @Environment(\.presentationMode) var presentationMode
    @State private var birdList: [[String]] = []
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Headbar
                HeadBarView(
                    title: countryName,
                    countryCode: CountryCodeManager.shared.getCountryCode(for: countryName),
                    onBackButtonTap: {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                )
                .padding(.top, geometry.safeAreaInsets.top)
                
                // 主要内容
                ScrollView {
                    VStack(spacing: 15) {
                        if enableBirdWatching && totalBirdSpeciesCount > 0 {
                            Text("\(totalBirdSpeciesCount) Bird Species Photographed")
                                .font(.headline)
                                .foregroundColor(Color("TUIBLUE"))
                                .padding(.vertical, 5)
                        }
                        
                        LazyVStack(alignment: .leading, spacing: 15) {
                            ForEach(groupedLocalities, id: \.area) { areaData in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        NavigationLink(destination: StatePhotoListView(area: areaData.area)) {
                                            Text(areaData.area)
                                                .font(.title2)
                                                .foregroundColor(.white)
                                            Spacer()
                                            if enableBirdWatching && areaData.birdSpeciesCount > 0 {
                                                Text("\(areaData.birdSpeciesCount) birds")
                                                    .font(.title3)
                                                    .foregroundColor(Color("Flare"))
                                            }
                                            Text("\(areaData.totalPhotos) photos")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color("TUIBLUE"))
                                    .cornerRadius(8)
                                    
                                    ForEach(areaData.localities) { locality in
                                        NavigationLink(destination: LocalityPhotoListView(locality: locality.name)) {
                                            HStack {
                                                Text(locality.name)
                                                    .font(.title3)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                if enableBirdWatching && locality.birdSpeciesCount > 0 {
                                                    Text("\(locality.birdSpeciesCount) birds")
                                                        .font(.subheadline)
                                                        .foregroundColor(.blue)
                                                }
                                                Text("\(locality.totalPhotos) photos")
                                                    .font(.subheadline)
                                                    .foregroundColor(Color("TUIBLUE"))
                                                Image(systemName: "chevron.right")
                                                    .font(.subheadline)
                                                    .foregroundColor(.blue)
                                            }
                                            .padding(.horizontal, 15)
                                            .padding(.vertical, 5)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.vertical, 5)
                                .cornerRadius(10)
                                .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color("BGColor"))

                // 底部导航栏
                BottomBarView()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
            }
            .edgesIgnoringSafeArea(.all)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadBirdList()
            loadLocalitiesAndBirdSpecies()
        }
        .onReceive(NotificationCenter.default.publisher(for: .birdWatchingStatusChanged)) { _ in
            loadLocalitiesAndBirdSpecies()
        }
    }

    private func loadBirdList() {
        do {
            guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json") else {
                return
            }
            let data = try Data(contentsOf: url)
            birdList = try JSONDecoder().decode([[String]].self, from: data)
        } catch {
            print("Debug: Error loading bird list: \(error.localizedDescription)")
        }
    }

    private func isBird(_ objectName: String) -> Bool {
        return birdList.contains { birdNames in
            birdNames.contains(objectName)
        }
    }

    private func loadLocalitiesAndBirdSpecies() {
        let rawData = SQLiteManager.shared.getAllPhotos()
        var localityDict = [String: (area: String, photoCount: Int, birdSpecies: Set<String>)]()
        var areaDict = [String: (photoCount: Int, birdSpecies: Set<String>)]()
        var totalBirdSpecies = Set<String>()
        
        for photo in rawData where photo.country == countryName && !photo.locality.isEmpty {
            var localityData = localityDict[photo.locality] ?? (area: photo.area, photoCount: 0, birdSpecies: Set<String>())
            localityData.photoCount += 1
            if !photo.objectName.isEmpty && isBird(photo.objectName) {
                localityData.birdSpecies.insert(photo.objectName)
                totalBirdSpecies.insert(photo.objectName)
            }
            localityDict[photo.locality] = localityData

            var areaData = areaDict[photo.area] ?? (photoCount: 0, birdSpecies: Set<String>())
            areaData.photoCount += 1
            if !photo.objectName.isEmpty && isBird(photo.objectName) {
                areaData.birdSpecies.insert(photo.objectName)
            }
            areaDict[photo.area] = areaData
        }
        
        var groupedDict = [String: [LocalityData]]()
        for (locality, data) in localityDict {
            let localityData = LocalityData(name: locality, totalPhotos: data.photoCount, birdSpeciesCount: data.birdSpecies.count)
            if groupedDict[data.area] != nil {
                groupedDict[data.area]?.append(localityData)
            } else {
                groupedDict[data.area] = [localityData]
            }
        }
        
        // 对每个 area 内的 localities 按照照片数量排序
        for (area, localities) in groupedDict {
            groupedDict[area] = localities.sorted { $0.totalPhotos > $1.totalPhotos }
        }
        
        // 创建最终的分组数据，包括每个 area 的总照片数和鸟类种数
        self.groupedLocalities = groupedDict.map { (area, localities) in
            let areaData = areaDict[area] ?? (photoCount: 0, birdSpecies: Set<String>())
            return (area: area, totalPhotos: areaData.photoCount, birdSpeciesCount: areaData.birdSpecies.count, localities: localities)
        }.sorted { $0.totalPhotos > $1.totalPhotos } // 按 area 的总照片数排序
        
        self.totalBirdSpeciesCount = totalBirdSpecies.count
    }
}

struct LocalityData: Identifiable {
    let id = UUID()
    let name: String
    let totalPhotos: Int
    let birdSpeciesCount: Int
}
