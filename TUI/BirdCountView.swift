import SwiftUI

struct BirdCountView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var birdCounts: [(String, Int, String, String)] = [] // (鸟类名称, 照片数量, 最早时间, 最新照片缩略图路径)
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var documentDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HeadBarView(title: "Bird Count")
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
                        } else if birdCounts.isEmpty {
                            Text("No bird records found")
                                .padding()
                        } else {
                            Text("Found \(birdCounts.count) bird species")
                                .font(.caption2)
                                .padding(.leading, 16)
                                .padding(.top, 8)

                            ForEach(Array(birdCounts.enumerated()), id: \.element.0) { index, birdData in
                                let (bird, count, earliestTime, thumbnailPath) = birdData
                                NavigationLink(destination: ObjectNameView(objectName: bird)) {
                                    HStack {
                                        Text("No.\(index + 1)")
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                            .frame(minWidth: 50, alignment: .leading)
                                        
                                        AsyncImage(url: getFullImagePath(for: thumbnailPath)) { phase in
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
                                            Text(bird)
                                                .foregroundColor(.primary)
                                            Text("First seen: \(formatDate(earliestTime))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("\(count)")
                                            .foregroundColor(.secondary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
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
        .onAppear(perform: loadBirdCounts)
    }

    private func loadBirdCounts() {
        if let cachedCounts = BirdCountCache.shared.birdCounts, !BirdCountCache.shared.shouldUpdate() {
            self.birdCounts = cachedCounts
            return
        }
        
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .background).async {
            do {
                let allObjectNames = SQLiteManager.shared.getAllObjectNames()
                let birdList = try loadBirdList()
                let earliestPhotoTimes = SQLiteManager.shared.getEarliestPhotoTimeForBirds()
                let latestPhotoInfo = SQLiteManager.shared.getLatestPhotoInfoForBirds()
                
                let filteredBirdCounts = allObjectNames.filter { objectName, _ in
                    birdList.contains { birdNames in
                        birdNames.contains(objectName)
                    }
                }
                
                let sortedBirdCounts = filteredBirdCounts.compactMap { (objectName, count) -> (String, Int, String, String)? in
                    if let earliestTime = earliestPhotoTimes.first(where: { $0.0 == objectName })?.1,
                       let latestPhotoThumbnail = latestPhotoInfo.first(where: { $0.0 == objectName })?.1 {
                        return (objectName, count, earliestTime, latestPhotoThumbnail)
                    }
                    return nil
                }.sorted { $0.2 < $1.2 }
                
                DispatchQueue.main.async {
                    self.birdCounts = sortedBirdCounts
                    BirdCountCache.shared.update(with: sortedBirdCounts)
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func loadBirdList() throws -> [[String]] {
        guard let url = Bundle.main.url(forResource: "birdInfo", withExtension: "json") else {
            throw NSError(domain: "BirdCountView", code: 1, userInfo: [NSLocalizedDescriptionKey: "birdInfo.json file not found"])
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([[String]].self, from: data)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateFormat = "MMM d, yyyy"
            return dateFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func getFullImagePath(for relativePath: String) -> URL {
        return documentDirectory.appendingPathComponent(relativePath)
    }
}

struct BirdCountView_Previews: PreviewProvider {
    static var previews: some View {
        BirdCountView()
    }
}
