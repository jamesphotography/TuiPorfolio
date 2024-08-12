import SwiftUI

struct LocalityListView: View {
    let countryName: String
    @State private var groupedLocalities: [(area: String, totalPhotos: Int, localities: [LocalityData])] = []
    @Environment(\.presentationMode) var presentationMode
    
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
                    LazyVStack(alignment: .leading, spacing: 15) {
                        ForEach(groupedLocalities, id: \.area) { areaData in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(areaData.area)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(areaData.totalPhotos) photos")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color("TUIBLUE"))
                                .cornerRadius(8)
                                
                                ForEach(areaData.localities) { locality in
                                    NavigationLink(destination: LocalityPhotoListView(locality: locality.name)) {
                                        HStack {
                                            Text(locality.name)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text("\(locality.totalPhotos)")
                                                .font(.caption)
                                                .foregroundColor(Color("TUIBLUE"))
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
            loadLocalities()
        }
    }

    private func loadLocalities() {
        let rawData = SQLiteManager.shared.getAllPhotos()
        var localityDict = [String: (area: String, count: Int)]()
        var areaDict = [String: Int]()
        
        for photo in rawData {
            if photo.country == countryName && !photo.locality.isEmpty {
                if let existingData = localityDict[photo.locality] {
                    localityDict[photo.locality] = (area: existingData.area, count: existingData.count + 1)
                } else {
                    localityDict[photo.locality] = (area: photo.area, count: 1)
                }
                areaDict[photo.area, default: 0] += 1
            }
        }
        
        var groupedDict = [String: [LocalityData]]()
        for (locality, data) in localityDict {
            let localityData = LocalityData(name: locality, totalPhotos: data.count)
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
        
        // 创建最终的分组数据，包括每个 area 的总照片数
        self.groupedLocalities = groupedDict.map { (area, localities) in
            (area: area, totalPhotos: areaDict[area] ?? 0, localities: localities)
        }.sorted { $0.totalPhotos > $1.totalPhotos } // 按 area 的总照片数排序
    }
}

struct LocalityData: Identifiable {
    let id = UUID()
    let name: String
    let totalPhotos: Int
}
